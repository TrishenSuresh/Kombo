#!/bin/bash

# Base input and output directories
INPUT_DIR="/input"
OUTPUT_DIR="/output"
NEW_EXTENSION="${FORMAT:-.epub}"
NO_KEPUB="${NO_KEPUB:false}"

# File to keep track of processed files
PROCESSED_FILES_LOG="/config/processed_files.log"

# Create the processed files log if it doesn't exist
touch "$PROCESSED_FILES_LOG"

# Initialize with null byte
printf '\0' > "$PROCESSED_FILES_LOG"

process_file() {
  local INPUT_FILE="$1"
  local OUTPUT_FILE="$2"

  if [[ ! -f "$OUTPUT_FILE" ]]; then
    # Check if the file has been processed before
    if ! grep -qF "$INPUT_FILE" "$PROCESSED_FILES_LOG" 2>/dev/null; then
      # Convert it
      echo "Processing file: $INPUT_FILE -> $OUTPUT_FILE"

      # Create the corresponding output directory structure
      mkdir -p "$(dirname "$OUTPUT_FILE")"

      echo "Using the following parameters: $INPUT_FILE ${NO_KEPUB:+--nokepub} --forcecolor --profile $PROFILE --upscale --output $(dirname "$OUTPUT_FILE")"
      python3 kcc/kcc-c2e.py "$INPUT_FILE" ${NO_KEPUB:+--nokepub} --forcecolor --profile "$PROFILE" --upscale --output "$(dirname "$OUTPUT_FILE")"
      # Log the processed input file (use null byte delimiter for safety with spaces)
      printf '%s\0' "$INPUT_FILE" >>"$PROCESSED_FILES_LOG"
      # Remove the converted CBZ/CBR file after successful conversion
      rm -f "$INPUT_FILE"
    else
      echo "File already processed: $INPUT_FILE"
    fi
  else
    echo "Output file already exists, skipping: $OUTPUT_FILE"
  fi
}

# Initial check: Process all existing files in the input directory
find "$INPUT_DIR" -type f -print0 | while IFS= read -r -d '' INPUT_FILE; do
    RELATIVE_PATH="${INPUT_FILE#$INPUT_DIR/}"
    OUTPUT_FILE="$OUTPUT_DIR/${RELATIVE_PATH%.*}.$NEW_EXTENSION"
    process_file "$INPUT_FILE" "$OUTPUT_FILE"
done

# Monitor the input folder for changes and cleanup
inotifywait -m -r -e close_write,moved_to,create "$INPUT_DIR" -q |
  while read -r directory events filename; do
    # Full path of the new or modified file
    INPUT_FILE="$directory$filename"
    # Calculate the relative path of the file within the input directory
    RELATIVE_PATH="${INPUT_FILE#$INPUT_DIR/}"
    # Remove the current extension and add the new one
    OUTPUT_FILE="$OUTPUT_DIR/${RELATIVE_PATH%.*}.$NEW_EXTENSION"
    # Process the new or modified file
    process_file "$INPUT_FILE" "$OUTPUT_FILE"
  done &

# Cleanup function: Remove empty subfolders from input directory
cleanup_empty_folders() {
  # Find and remove empty directories (but keep the input directory itself)
  find "$INPUT_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
}

# Run cleanup periodically (every 60 seconds)
cleanup_empty_folders
while true; do
  cleanup_empty_folders
  sleep 60
done
