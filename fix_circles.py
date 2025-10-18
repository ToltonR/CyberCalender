import re

# Read the file
with open('Calendar.ini', 'r', encoding='utf-8') as f:
    content = f.read()

# Define all X positions for the 7 columns (text positions)
x_positions = [40, 90, 140, 190, 240, 290, 340]
# Define all Y positions for the 6 rows (text positions)
y_positions = [140, 175, 210, 245, 280, 315]

# Generate all 42 day indices with their coordinates
day_coords = []
for row, y in enumerate(y_positions):
    for col, x in enumerate(x_positions):
        index = row * 7 + col
        day_coords.append((index, x, y))

# Fix each background meter
for index, text_x, text_y in day_coords:
    # Calculate centered position for the ellipse
    # The ellipse shape is: Ellipse CenterX,CenterY,Radius
    # We want the circle centered at the text position
    # Text is centered at text_x with StringAlign=Center
    # So the circle center should be at text_x relative to the shape meter

    # Place the shape meter at text_x - 22 (so ellipse center at 22 aligns with text_x)
    bg_x = text_x - 17  # Adjusted for better centering
    bg_y = text_y - 2   # Adjusted for better vertical centering

    # Old pattern - match the entire MeterDayXBG section
    old_pattern = rf'\[MeterDay{index}BG\]\s*\n\s*Meter=Shape\s*\n\s*X=\d+\s*\n\s*Y=\d+\s*\n\s*Shape=Ellipse [^\n]+\n'

    # New replacement with smaller circle (radius 16 instead of 20)
    new_replacement = f'[MeterDay{index}BG]\nMeter=Shape\nX={bg_x}\nY={bg_y}\nShape=Ellipse 17,17,16 | Fill Color [&MeasureCalendarScript:GetTodayBG({index})] | StrokeWidth 0\n'

    content = re.sub(old_pattern, new_replacement, content)

# Write back
with open('Calendar.ini', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed all 42 day background circles with smaller size and better centering!")
