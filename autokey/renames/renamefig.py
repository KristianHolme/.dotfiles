import time
#renames B_name_more_names_here.ext to B_name.ext

# Press F2 to start renaming the file
keyboard.send_keys('<f2>')

# Wait for a bit (adjust the time if necessary)
time.sleep(0.1)

# Press right arrow key to move the cursor to the end of the filename
keyboard.send_keys('<right>')

# select text
keyboard.send_keys('<shift>+<home>')

# Press Ctrl+Right twice to move the cursor to after first two names
keyboard.send_keys('<ctrl>+<shift>+<right>')

keyboard.send_keys('<ctrl>+<shift>+<right>')

# Press Delete to delete the selected part of the filename
keyboard.send_keys('<delete>')

#save
keyboard.send_keys('<enter>')