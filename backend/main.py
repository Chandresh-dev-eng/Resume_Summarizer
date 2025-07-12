from flask import Flask, request, jsonify
from flask_cors import CORS
from transformers import pipeline
import fitz  # PyMuPDF
import tempfile
import os

app = Flask(__name__)
CORS(app)
summarizer = pipeline("summarization", model="facebook/bart-large-cnn")

# Clean extracted text
def clean_text(raw_text):
    lines = raw_text.splitlines()
    cleaned = []
    for line in lines:
        line = line.strip()
        if not line or len(line) < 30:
            continue
        if any(x in line.lower() for x in ["http", "linkedin", "cnn", "snapshots"]):
            continue
        cleaned.append(line)
    return " ".join(cleaned)

# Extract text from PDF
def extract_text_from_pdf(file_stream):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
        tmp.write(file_stream.read())
        tmp_path = tmp.name

    doc = fitz.open(tmp_path)
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    os.remove(tmp_path)
    return text

# Break large text into chunks for summarization
def chunk_text(text, max_chunk_len=1000):
    sentences = text.split(". ")
    chunks, chunk = [], ""
    for sentence in sentences:
        if len(chunk) + len(sentence) <= max_chunk_len:
            chunk += sentence + ". "
        else:
            chunks.append(chunk.strip())
            chunk = sentence + ". "
    if chunk:
        chunks.append(chunk.strip())
    return chunks

@app.route('/summarize', methods=['POST'])
def summarize_resume():
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    raw_text = extract_text_from_pdf(file)
    cleaned_text = clean_text(raw_text)

    if len(cleaned_text) < 100:
        return jsonify({"error": "Resume too short or unreadable."}), 400

    chunks = chunk_text(cleaned_text, 1000)

    summaries = []
    for chunk in chunks:
        result = summarizer(chunk, max_length=150, min_length=40, do_sample=False)
        summaries.append(result[0]['summary_text'])

    full_summary = " ".join(summaries)
    return jsonify({"summary": full_summary})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

