# main.py
import re
import os
import gc
import tempfile
from flask import Flask, request, jsonify
from unsloth import FastModel
import torch
from transformers import TextStreamer

# --- Configuration & Model Loading ---
# This section loads the model and tokenizer once when the application starts.
# This is much more efficient than reloading the model for every API request.

print("Loading model... This may take a few minutes.")

# MODEL_NAME = "unsloth_gemma-3n-E2B-it-unsloth-bnb-4bit"
MODEL_NAME = "gemma-3n"
MAX_SEQ_LENGTH = 1024 # Adjust as needed for your context length requirements

# Load the model with 4-bit quantization
try:
    model, tokenizer = FastModel.from_pretrained(
        model_name=MODEL_NAME,
        dtype=None,  # Auto-detection
        max_seq_length=MAX_SEQ_LENGTH,
#        load_in_4bit=True,
#        full_finetuning=False,
    )
    print(model)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    # Exit if the model fails to load
    exit()

# Initialize Flask App
app = Flask(__name__)

# --- Helper Function for Inference ---
# This function is adapted to return the generated text instead of streaming to the console.
def do_gemma_3n_inference(model, tokenizer, messages, max_new_tokens=256):
    """
    Performs inference on the provided messages, captures the generated text, and returns it.
    """
    # Apply the chat template to format the input correctly
    inputs = tokenizer.apply_chat_template(
        messages,
        add_generation_prompt=True,  # Crucial for generation tasks
        tokenize=True,
        return_dict=True,
        return_tensors="pt",
    ).to("cuda")

    # Generate the text output
    # We remove the streamer to capture the output instead of printing it
    outputs = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        temperature=1.0,
        top_p=0.95,
        top_k=64,
        use_cache=True, # Important for generation speed
    )
    
    # Decode the generated tokens into a string
    # We decode only the newly generated tokens, skipping the input prompt
    generated_text = tokenizer.batch_decode(outputs[:, inputs.input_ids.shape[1]:], skip_special_tokens=True)[0]
    print(generated_text)

    # Cleanup to reduce VRAM usage after each inference
    del inputs
    del outputs
    torch.cuda.empty_cache()
    gc.collect()
    
    return generated_text

# --- API Endpoint ---
@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    """
    API endpoint to receive an audio file and a text prompt.
    It returns a JSON response with the model's description of the audio.
    
    To use this endpoint, send a POST request with:
    - A file part named 'audio' containing the audio file.
    - A form field named 'prompt' with the text question (e.g., "What is this audio about?").
    """
    # Check if the audio file is in the request
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files['audio']
    
    # Check if the filename is empty
    if audio_file.filename == '':
        return jsonify({"error": "No audio file selected"}), 400

    # Get the text prompt from the form data
    prompt = request.form.get('prompt', "What is this audio about?")

    # Create a temporary file to save the uploaded audio
    # Using a context manager ensures the file is deleted automatically
    try:
        with tempfile.NamedTemporaryFile(delete=True, suffix=os.path.splitext(audio_file.filename)[1]) as temp_audio:
            audio_file.save(temp_audio.name)
            
            print(f"Processing audio file: {audio_file.filename} with prompt: '{prompt}'")

            # Prepare the messages payload for the model
            messages = [
            {
                "role": "system",
                "content": [
                    {
                        "type": "text",
                        "text": "You are an assistant that transcribes speech accurately.",
                    }
                ],
            },
            {
                "role": "user",
                "content": [
                    {"type": "audio", "audio": temp_audio.name},
                    {"type": "text",  "text": prompt}
                ]
            }]
            print(messages)

            # Run inference
            try:
                description = do_gemma_3n_inference(model, tokenizer, messages)
                print(f"Generated Description: {description}")
                    # Regex to find the content inside the <ASL> tags
                asl_match = re.search(r"<ASL>(.*?)</ASL>", description)

                if asl_match:
                    # Extract the English text (before the <ASL> tag)
                    text = description.split("<ASL>")[0].strip()
                    # Extract the ASL gloss
                    asl_gloss = asl_match.group(1).strip()
                else:
                    # If no <ASL> tag is found, the whole text is treated as both
                    text = description.strip()
                    asl_gloss = description.strip()

                return jsonify({"text": text, "asl_gloss": asl_gloss})
            except Exception as e:
                print(f"Inference Error: {e}")
                return jsonify({"error": f"An error occurred during model inference: {e}"}), 500

    except Exception as e:
        print(f"File Handling Error: {e}")
        return jsonify({"error": f"An error occurred processing the file: {e}"}), 500

# --- Main Application Runner ---
if __name__ == '__main__':
    # Runs the Flask app on http://127.0.0.1:5000
    # Use host='0.0.0.0' to make it accessible on your local network
    app.run(host='0.0.0.0', port=5000, debug=False)
