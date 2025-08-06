import pandas as pd
from datasets import load_dataset
from tqdm import tqdm
import time
from datetime import timedelta
from vllm import LLM, SamplingParams

# --- vLLM Configuration ---
VLLM_MODEL = "google/gemma-3n-E4B-it"

# --- Batching Configuration ---
BATCH_SIZE = 8

# --- Output Configuration ---
OUTPUT_DATASET_DIR = "english_dialects_asl_gloss_vllm_batched"

# --- [CRITICAL CHANGE 1] - Prompt Template using Gemma's Chat Format ---
# We wrap the prompt in the model's required chat structure. This significantly
# improves its adherence to the instructions.
PROMPT_TEMPLATE = """<start_of_turn>user
You are an expert ASL Linguistics assistant. Your task is to accurately translate English sentences into standard American Sign Language (ASL) Gloss. You must follow the rules and thinking process below precisely and provide ONLY the ASL Gloss output. Do not include explanations.

**Thinking Process to Follow:**
1.  **Analyze & Simplify:** Read the English sentence and remove all unnecessary words (articles, linking verbs) and convert all words to their base form (e.g., "running" -> RUN).
2.  **Identify Fingerspelling:** Identify all proper nouns (names like "Amir," places, brands) that must be fingerspelled with `fs-`.
3.  **Determine Word Order:** Rearrange the core concepts into ASL grammar, which is typically **TIME - TOPIC - COMMENT**. The question word (WH-word) always goes at the very end.
4.  **Assemble Final Gloss:** Build the final gloss using the strict rules below.

**Crucial Examples of Correct Translation:**

English: "He is sitting in a chair."
ASL Gloss:
CHAIR, IX-he SIT.

English: "Amir is tall."
ASL Gloss:
fs-AMIR IX-he TALL

English: "The boy cried and cried."
ASL Gloss:
BOY IX-he CRY++

---
Now, following all rules and the thinking process, translate the sentence below. Provide ONLY the ASL Gloss.

English Sentence: "{english_text}"<end_of_turn>
<start_of_turn>model
ASL Gloss:
"""

# --- [CRITICAL CHANGE 2] - Robust Parsing Function ---
def parse_model_output(raw_output: str) -> str:
    """
    Cleans the raw output from the LLM to isolate the ASL Gloss.
    Handles cases where the model adds conversational preamble.
    """
    # The model might repeat "ASL Gloss:" in its output. We split by this
    # phrase and take the last part, which should be the actual translation.
    if "ASL Gloss:" in raw_output:
        # Get the content after the last "ASL Gloss:"
        gloss_part = raw_output.split("ASL Gloss:")[-1]
    else:
        # If the model behaves perfectly, the phrase might not be there
        gloss_part = raw_output
        
    # Final cleanup: remove leading/trailing whitespace and any stray quotes
    cleaned_gloss = gloss_part.strip().strip('"').strip()
    
    return cleaned_gloss if cleaned_gloss else "ERROR: PARSING FAILED"

def main():
    """
    Main function to load data, process it in batches with vLLM, and save the dataset.
    """
    print(f"Loading model '{VLLM_MODEL}' with vLLM...")
    try:
        llm = LLM(model=VLLM_MODEL)
    except Exception as e:
        print(f"Error loading LLM: {e}")
        return

    print("Loading 'ai4bharat/Svarah' dataset from Hugging Face...")
    try:
        # Use a configuration that has audio data, 'hi' for Hindi for example
        dataset = load_dataset("openslr/librispeech_asr", "clean", split="train.100")
    except Exception as e:
        print(f"Failed to load dataset. Error: {e}")
        return
    
    # FOR TESTING
    # dataset = dataset.select(range(200))

    total_records = len(dataset)
    print(f"Dataset loaded successfully with {total_records} records.")

    print(f"\nStarting ASL Gloss generation for {total_records} records in batches of {BATCH_SIZE}...")
    
    # Increased max_tokens slightly as a safeguard for longer translations
    sampling_params = SamplingParams(temperature=0.2, top_p=0.95, max_tokens=200)
    all_generated_glosses = []
    
    start_time = time.time()
    
    for i in tqdm(range(0, total_records, BATCH_SIZE), desc="Processing in batches"):
        batch_texts = dataset[i : i + BATCH_SIZE]['text']
        batch_prompts = [PROMPT_TEMPLATE.format(english_text=text) for text in batch_texts]
        batch_outputs = llm.generate(batch_prompts, sampling_params)
        
        # Use the robust parsing function here
        batch_glosses = [parse_model_output(output.outputs[0].text) for output in batch_outputs]
        all_generated_glosses.extend(batch_glosses)
        
    end_time = time.time()
    
    total_duration = end_time - start_time
    avg_time_per_record = total_duration / total_records if total_records > 0 else 0

    print("\n--- Generation Summary ---")
    print(f"Total records processed: {total_records}")
    print(f"Total time taken: {timedelta(seconds=total_duration)}")
    print(f"Average time per record: {avg_time_per_record:.4f} seconds")
    print("--------------------------\n")

    print("Adding the 'asl_gloss' column to the dataset...")
    if len(all_generated_glosses) != total_records:
        print(f"Error: Mismatch in record count. Expected {total_records}, but got {len(all_generated_glosses)} glosses.")
        return

    updated_dataset = dataset.add_column("asl_gloss", all_generated_glosses)
    
    print(f"Saving the new dataset to the directory: '{OUTPUT_DATASET_DIR}'")
    try:
        updated_dataset.save_to_disk(OUTPUT_DATASET_DIR)
        print("\nDataset saved successfully!")
    except Exception as e:
        print(f"Failed to save the dataset. Error: {e}")

if __name__ == "__main__":
    main()
