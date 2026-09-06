uniform float uTime;

varying vec3 vNormal;
varying vec3 vViewDir;

void main() {
  vNormal = normalMatrix * normal;
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  vViewDir = -mv.xyz;
  gl_Position = projectionMatrix * mv;
}
