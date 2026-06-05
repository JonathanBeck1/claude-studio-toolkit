// Fresnel + iridescence helpers
// Use: float f = fresnel(normal, viewDir, power);
//      vec3 c = iridescence(viewDot, palette);

float fresnel(vec3 normal, vec3 viewDir, float power) {
  return pow(1.0 - max(dot(normalize(normal), normalize(viewDir)), 0.0), power);
}

// 3-stop iridescent palette sampled by view-angle dot product
// palette is packed as 3 vec3 colors passed in, sampled smoothly
vec3 iridescence(float viewDot, vec3 c0, vec3 c1, vec3 c2) {
  float t = clamp(viewDot, 0.0, 1.0);
  if (t < 0.5) {
    return mix(c0, c1, t * 2.0);
  } else {
    return mix(c1, c2, (t - 0.5) * 2.0);
  }
}
