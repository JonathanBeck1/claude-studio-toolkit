// LUT-based color grading
// Sample a 3D LUT laid out as a 2D strip texture (typical: 256x16, 16 slices of 16x16)
// Use: color.rgb = applyLUT(uLutTexture, color.rgb);

vec3 applyLUT(sampler2D lut, vec3 color) {
  color = clamp(color, 0.0, 1.0);
  float blueSlice = color.b * 15.0;
  float sliceFloor = floor(blueSlice);
  float sliceFrac = blueSlice - sliceFloor;

  vec2 uvFloor = vec2(
    (sliceFloor * 16.0 + color.r * 15.0 + 0.5) / 256.0,
    (color.g * 15.0 + 0.5) / 16.0
  );
  vec2 uvCeil = vec2(
    ((sliceFloor + 1.0) * 16.0 + color.r * 15.0 + 0.5) / 256.0,
    (color.g * 15.0 + 0.5) / 16.0
  );

  vec3 sampleFloor = texture2D(lut, uvFloor).rgb;
  vec3 sampleCeil = texture2D(lut, uvCeil).rgb;
  return mix(sampleFloor, sampleCeil, sliceFrac);
}
