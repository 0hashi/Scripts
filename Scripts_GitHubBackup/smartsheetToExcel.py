import json
import pandas as pd

# Load the JSON file
with open('sheet_data.json', 'r') as file:
    data = json.load(file)

# Extract column titles and map column IDs to titles
columns = {col['id']: col['title'] for col in data['columns']}

# Build a list of rows
rows = []
for row in data['rows']:
    row_data = {}
    for cell in row['cells']:
        column_title = columns.get(cell['columnId'])
        row_data[column_title] = cell.get('value', '')
    rows.append(row_data)

# Convert to DataFrame
df = pd.DataFrame(rows)

# Save to Excel
df.to_excel('sheet_data.xlsx', index=False)
print("Conversion complete! Saved as sheet_data.xlsx")