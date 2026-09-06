precision highp float;

uniform vec3 uColorRimA;
uniform vec3 uColorRimB;
uniform float uFresnelExp;

varying vec3 vNormal;
varying vec3 vViewDir;

void main() {
  vec3 N = normalize(vNormal);
  vec3 V = normalize(vViewDir);
  float fresnel = pow(1.0 - max(dot(N, V), 0.0), uFresnelExp);
  vec3 rim = mix(uColorRimA, uColorRimB, smoothstep(-0.3, 0.6, N.y));
  gl_FragColor = vec4(rim * fresnel, 1.0);
}
