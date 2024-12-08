import openai
import time
import json

# Set up your API key directly
openai.api_key = "Enter OpenAI API Key here"
def show_json(obj):
    # Convert the thread or run object to a dictionary first before printing
    if hasattr(obj, 'to_dict'):
        obj = obj.to_dict()  # Convert the object to a dictionary if possible
    print(json.dumps(obj, indent=4))

# Create a thread
def create_thread():
    thread = openai.beta.threads.create()
    show_json(thread)
    return thread.id

# Add message to the thread
def add_message(thread_id, user_input):
    message = openai.beta.threads.messages.create(
        thread_id=thread_id,
        role="user",
        content=user_input
    )
    show_json(message)

# Run the assistant on the thread
def create_run(thread_id, assistant_id):
    run = openai.beta.threads.runs.create(
        thread_id=thread_id,
        assistant_id=assistant_id
    )
    return run

# Wait for the assistant to complete processing
def wait_on_run(run, thread_id):
    while run.status == "queued" or run.status == "in_progress":
        run = openai.beta.threads.runs.retrieve(
            thread_id=thread_id,
            run_id=run.id
        )
        time.sleep(0.5)
    return run

# List messages in the thread
def list_messages(thread_id):
    messages = openai.beta.threads.messages.list(thread_id=thread_id)
    show_json(messages)
    return messages

# Main function to handle the full flow
def get_assistant_response(user_input, assistant_id):
    thread_id = create_thread()  # Create a new thread
    add_message(thread_id, user_input)  # Add user's input message
    
    run = create_run(thread_id, assistant_id)  # Start a run for the assistant
    run = wait_on_run(run, thread_id)  # Wait for the assistant to complete processing
    
    # Retrieve all messages after the run is complete
    messages = list_messages(thread_id)
    
    # Iterate through the messages to find the assistant's response
    for message in messages.data:
        if message.role == "assistant":
            return message.content[0].text.value  # Return the assistant's response content
    
    return "No assistant response found."

if __name__ == "__main__":
    import sys
    user_input = sys.argv[1]  # Get the input passed from MATLAB or command line
    assistant_id = "asst_iLpw4dSw6O1Od3LM6W7TMhlQ"  # Replace with your existing assistant ID
    response = get_assistant_response(user_input, assistant_id)
    print(response)