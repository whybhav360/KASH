#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_is_dark;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    
    // Multi-layered organic flowing waves
    float t = u_time * 0.9;
    
    // Primary flowing wave pattern with distinct moving crests
    float wave1 = sin(uv.x * 2.8 + t * 0.8) * cos(uv.y * 2.2 - t * 0.6);
    float wave2 = sin((uv.x + uv.y) * 3.2 + t * 1.1) * 0.5;
    float wave3 = cos(length(uv - vec2(0.35, 0.45)) * 4.5 - t * 0.7) * 0.4;
    
    float wave = clamp((wave1 + wave2 + wave3) * 0.5 + 0.5, 0.0, 1.0);
    
    // Light mode palette: Rich brand indigo, soft pastel lavender (from splash_bg), and warm pearl
    vec3 lightBrandPrimary = vec3(0.31, 0.27, 0.90); // #4F46E5
    vec3 lightLavender     = vec3(0.76, 0.80, 0.98); // #C3CAF9
    vec3 lightWarmPearl    = vec3(0.96, 0.96, 0.99); // #F5F6FC
    
    // Dark mode palette: Deep midnight indigo, electric violet, deep obsidian
    vec3 darkBrandPrimary  = vec3(0.40, 0.36, 0.96); // #665CF5
    vec3 darkIndigoDeep    = vec3(0.14, 0.12, 0.38); // #241E61
    vec3 darkObsidian      = vec3(0.06, 0.05, 0.15); // #0F0D26
    
    vec3 col1 = mix(lightWarmPearl, darkObsidian, u_is_dark);
    vec3 col2 = mix(lightLavender, darkIndigoDeep, u_is_dark);
    vec3 col3 = mix(lightBrandPrimary, darkBrandPrimary, u_is_dark);
    
    // Clearly visible fluid color blend
    vec3 baseColor = mix(col1, col2, smoothstep(0.1, 0.6, wave));
    float accentMix = smoothstep(0.45, 0.85, wave) * (u_is_dark > 0.5 ? 0.55 : 0.32);
    vec3 finalColor = mix(baseColor, col3, accentMix);
    
    // Luminous ambient center glow behind the logo
    float distToCenter = length(uv - vec2(0.5, 0.42));
    float centerGlow = smoothstep(0.45, 0.0, distToCenter) * 0.18;
    finalColor += mix(vec3(0.15, 0.12, 0.40), vec3(0.30, 0.25, 0.70), u_is_dark) * centerGlow;
    
    // Soft vignette around edges for depth
    float vignette = length(uv - 0.5);
    finalColor *= 1.0 - vignette * 0.16;

    fragColor = vec4(finalColor, 1.0);
}
