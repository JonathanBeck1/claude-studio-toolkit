// 3D curl noise — divergence-free vector field for organic particle flow
// Source: based on Inigo Quilez and Pat Lefebvre's curl-of-noise derivations
// Returns: vec3 flow vector at position p

vec3 _hash3(vec3 p) {
  p = vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6))
  );
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float _noise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(
      mix(dot(_hash3(i + vec3(0,0,0)), f - vec3(0,0,0)),
          dot(_hash3(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
      mix(dot(_hash3(i + vec3(0,1,0)), f - vec3(0,1,0)),
          dot(_hash3(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x),
      u.y),
    mix(
      mix(dot(_hash3(i + vec3(0,0,1)), f - vec3(0,0,1)),
          dot(_hash3(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
      mix(dot(_hash3(i + vec3(0,1,1)), f - vec3(0,1,1)),
          dot(_hash3(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x),
      u.y),
    u.z);
}

vec3 curl(vec3 p) {
  const float e = 0.01;
  vec3 dx = vec3(e, 0.0, 0.0);
  vec3 dy = vec3(0.0, e, 0.0);
  vec3 dz = vec3(0.0, 0.0, e);

  vec3 p_x0 = vec3(_noise(p - dx), _noise(p - dx + vec3(31.4)), _noise(p - dx + vec3(73.2)));
  vec3 p_x1 = vec3(_noise(p + dx), _noise(p + dx + vec3(31.4)), _noise(p + dx + vec3(73.2)));
  vec3 p_y0 = vec3(_noise(p - dy), _noise(p - dy + vec3(31.4)), _noise(p - dy + vec3(73.2)));
  vec3 p_y1 = vec3(_noise(p + dy), _noise(p + dy + vec3(31.4)), _noise(p + dy + vec3(73.2)));
  vec3 p_z0 = vec3(_noise(p - dz), _noise(p - dz + vec3(31.4)), _noise(p - dz + vec3(73.2)));
  vec3 p_z1 = vec3(_noise(p + dz), _noise(p + dz + vec3(31.4)), _noise(p + dz + vec3(73.2)));

  float x = (p_y1.z - p_y0.z) - (p_z1.y - p_z0.y);
  float y = (p_z1.x - p_z0.x) - (p_x1.z - p_x0.z);
  float z = (p_x1.y - p_x0.y) - (p_y1.x - p_y0.x);

  return normalize(vec3(x, y, z) / (2.0 * e));
}
