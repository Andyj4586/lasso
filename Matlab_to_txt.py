import os

def combine_matlab_files(input_directory, output_filename):
    try:
        # Open the output text file for writing
        with open(output_filename, 'w', encoding='utf-8') as output_file:
            
            # Iterate over all files in the directory
            for filename in os.listdir(input_directory):
                
                # Check if the file is a MATLAB .m or .mlapp file
                if filename.endswith('.m') or filename.endswith('.mlapp'):
                    filepath = os.path.join(input_directory, filename)
                    
                    # Write a header for each file
                    output_file.write(f'\n%% Content from: {filename} \n')
                    
                    # Try reading the file with utf-8, fall back to latin-1 if it fails
                    try:
                        with open(filepath, 'r', encoding='utf-8') as matlab_file:
                            content = matlab_file.read()
                    except UnicodeDecodeError:
                        with open(filepath, 'r', encoding='latin-1') as matlab_file:
                            content = matlab_file.read()
                    
                    # Write content to the output file
                    output_file.write(content)
                    output_file.write('\n')  # Separate content from each file
        
        print(f"Successfully combined MATLAB files into '{output_filename}'")
    except Exception as e:
        print(f"An error occurred: {e}")

# Usage example
input_directory = os.path.expanduser('~/Redstone_Project/LASSO')  # Path to your MATLAB files
output_filename = 'combined_matlab_code.txt'   # Replace with desired output file name
combine_matlab_files(input_directory, output_filename)
