from PIL import Image, ImageDraw

# Create a 512x512 image with white background
size = 512
img = Image.new('RGB', (size, size), 'white')
draw = ImageDraw.Draw(img)

# Center point
cx, cy = size // 2, size // 2

# Yellow color for bell
bell_color = '#FFC107'
dark_bell = '#FFA000'

# Draw bell body (simplified polygon shape)
bell_points = [
    (cx, cy - 100),  # Top
    (cx - 80, cy - 60),  # Upper left
    (cx - 70, cy + 80),  # Lower left
    (cx + 70, cy + 80),  # Lower right
    (cx + 80, cy - 60),  # Upper right
]
draw.polygon(bell_points, fill=bell_color)

# Draw bell top knob (circle)
knob_radius = 20
draw.ellipse([cx - knob_radius, cy - 110 - knob_radius, 
              cx + knob_radius, cy - 110 + knob_radius], fill=bell_color)

# Draw bell clapper (small circle at bottom)
clapper_radius = 25
draw.ellipse([cx - clapper_radius, cy + 60 - clapper_radius,
              cx + clapper_radius, cy + 60 + clapper_radius], fill=dark_bell)

# Save the image
img.save('assets/bell_icon.png')
print("✓ Bell icon created successfully at assets/bell_icon.png")
print("  Run: flutter pub run flutter_launcher_icons")
