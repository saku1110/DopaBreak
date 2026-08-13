#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float flameHash(float2 point) {
    float3 value = fract(float3(point.xyx) * float3(0.1031, 0.1030, 0.0973));
    value += dot(value, value.yxz + 33.33);
    return fract((value.x + value.y) * value.z);
}

static float flameValueNoise(float2 point) {
    float2 cell = floor(point);
    float2 fraction = fract(point);
    float2 curve = fraction * fraction * (3.0 - (2.0 * fraction));

    float bottom = mix(
        flameHash(cell),
        flameHash(cell + float2(1.0, 0.0)),
        curve.x
    );
    float top = mix(
        flameHash(cell + float2(0.0, 1.0)),
        flameHash(cell + float2(1.0, 1.0)),
        curve.x
    );
    return mix(bottom, top, curve.y);
}

static float flameFBM(float2 point, int octaves) {
    float value = 0.0;
    float amplitude = 0.53;
    float2x2 rotation = float2x2(
        float2(0.80, -0.60),
        float2(0.60, 0.80)
    );

    for (int octave = 0; octave < 4; octave++) {
        if (octave >= octaves) {
            break;
        }
        value += flameValueNoise(point) * amplitude;
        point = (rotation * point) * 2.04 + float2(17.1, 9.2);
        amplitude *= 0.49;
    }
    return saturate(value);
}

static float flameVerticalFBM(float2 point, int octaves) {
    float value = 0.0;
    float amplitude = 0.54;
    float normalization = 0.0;

    for (int octave = 0; octave < 4; octave++) {
        if (octave >= octaves) {
            break;
        }
        value += flameValueNoise(point) * amplitude;
        normalization += amplitude;
        point = float2(
            point.x * 2.08 + point.y * 0.120,
            point.y * 1.54 - point.x * 0.035
        ) + float2(13.7, 7.9);
        amplitude *= 0.49;
    }
    return saturate(value / max(normalization, 0.001));
}

static float flameRidged(float noiseValue, float sharpness) {
    float ridge = 1.0 - abs((noiseValue * 2.0) - 1.0);
    return pow(saturate(ridge), sharpness);
}

[[ stitchable ]] half4 flame(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float intensity,
    float flare,
    float reduceMotion
) {
    (void)currentColor;

    size = select(float2(1.0), size, isfinite(size));
    time = select(0.0, time, isfinite(time));
    intensity = select(0.0, intensity, isfinite(intensity));
    flare = select(0.0, flare, isfinite(flare));
    reduceMotion = select(0.0, reduceMotion, isfinite(reduceMotion));

    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float y = 1.0 - uv.y;
    float centeredX = uv.x - 0.5;

    intensity = saturate(intensity);
    flare = saturate(flare);
    reduceMotion = saturate(reduceMotion);

    float motionAmount = 1.0 - reduceMotion;
    float flowTime = time * mix(0.032, 0.30, motionAmount);
    float turbulence = mix(0.020, 0.118, motionAmount);
    int octaves = reduceMotion > 0.5 ? 3 : 4;

    float energy = mix(0.58, 1.0, intensity) + flare * 0.48;
    float flickerNoise = flameValueNoise(
        float2(time * mix(0.08, 1.16, motionAmount), 12.7)
    ) - 0.5;
    float flameHeight = mix(0.50, 0.78, intensity) + flare * 0.125;
    flameHeight *= 1.0 + flickerNoise * mix(0.002, 0.015, motionAmount);
    flameHeight = min(flameHeight, 0.91);

    float heightProgress = y / max(flameHeight, 0.001);
    float clampedHeight = saturate(heightProgress);
    float baseWidth = mix(0.120, 0.215, intensity) + flare * 0.052;

    float warpNoiseA = flameFBM(
        float2(
            heightProgress * 0.62 - flowTime * 0.58,
            heightProgress * 0.31 + 7.4
        ),
        octaves
    );
    float warpNoiseB = flameFBM(
        float2(
            heightProgress * 0.39 + 19.2,
            heightProgress * 0.54 - flowTime * 0.43
        ),
        octaves
    );
    float accumulatedWarp = pow(clampedHeight, 1.5);
    float lateralWarp = (warpNoiseA - 0.5) * 1.55
        + (warpNoiseB - 0.5) * 0.72;
    float warpedCenter = baseWidth * accumulatedWarp * (
        lateralWarp * turbulence * (3.10 + flare * 0.42)
            + sin(heightProgress * 5.7 - flowTime * 3.1) * turbulence * 0.38
            + 0.055
    );
    float plumeX = centeredX - warpedCenter;

    float taper = 1.0 - 0.38 * pow(clampedHeight, 0.82);
    float plumeWidth = baseWidth * max(taper, 0.62);
    float crossSection = 1.0 - smoothstep(
        plumeWidth * 0.045,
        plumeWidth,
        abs(plumeX)
    );
    crossSection = pow(saturate(crossSection), 1.05);

    float normalizedPlumeX = plumeX / max(baseWidth, 0.01);
    float normalizedCurrentX = plumeX / max(plumeWidth, 0.008);
    float2 plumePoint = float2(
        normalizedCurrentX * 4.0
            + (warpNoiseB - 0.5) * 0.95
            + lateralWarp * accumulatedWarp * 0.75,
        heightProgress * 0.88 - flowTime * 1.36
    );
    float risingNoise = flameVerticalFBM(
        plumePoint + float2(9.6, 23.1),
        octaves
    );
    float columnNoise = flameValueNoise(
        float2(
            normalizedCurrentX * 2.75 + 4.8,
            flowTime * 0.24 + 18.3
        )
    );
    float crestNoise = flameValueNoise(
        float2(
            normalizedCurrentX * 6.4
                + heightProgress * 0.36
                + flowTime * 0.15,
            heightProgress * 0.34 - flowTime * 0.91 + 31.7
        )
    );
    float combinedPlumeNoise = risingNoise * 0.56
        + columnNoise * 0.29
        + crestNoise * 0.15;
    float plumeNoise = mix(
        0.38,
        1.0,
        smoothstep(0.28, 0.75, combinedPlumeNoise)
    );
    plumeNoise += (1.0 - saturate(abs(normalizedPlumeX))) * 0.015;
    plumeNoise = saturate(plumeNoise);

    float heightFalloff = mix(0.680, 0.635, saturate(energy - 0.58));
    heightFalloff -= flare * 0.105;
    float rawDensity = plumeNoise * crossSection
        - heightProgress * heightFalloff;
    float flareBodySupport = smoothstep(-0.105, 0.060, rawDensity);
    float flareBodyEnvelope = 1.0 - smoothstep(
        0.66,
        1.10,
        heightProgress
    );
    rawDensity += flare
        * flareBodySupport
        * flareBodyEnvelope
        * crossSection
        * mix(0.16, 0.34, plumeNoise);

    float rootBreakup = flameValueNoise(
        float2(normalizedPlumeX * 4.3 + flowTime * 0.23, 41.6)
    );
    float rootEdge = pow(saturate(abs(normalizedPlumeX)), 1.45);
    float rootStart = 0.006 + rootBreakup * 0.050 + rootEdge * 0.040;
    float rootFade = smoothstep(rootStart, rootStart + 0.045, y);

    float density = smoothstep(0.018, 0.190, rawDensity) * rootFade;
    density *= 1.0 + flare * 0.26;
    float densityPresence = smoothstep(
        -flare * 0.024,
        0.055 - flare * 0.018,
        rawDensity
    ) * rootFade;

    float2 streamPointA = float2(
        normalizedCurrentX * 2.90
            + lateralWarp * accumulatedWarp * 1.50
            + (risingNoise - 0.5) * 1.40
            + sin(heightProgress * 6.8 - flowTime * 2.4) * 0.48,
        heightProgress * 0.86 - flowTime * 1.66
    );
    float streamA = flameVerticalFBM(
        streamPointA + float2(-17.8, 5.4),
        octaves
    );
    float2 streamPointB = float2(
        normalizedCurrentX * 4.45
            - lateralWarp * accumulatedWarp * 1.10
            + (streamA - 0.5) * 1.42,
        heightProgress * 1.08 - flowTime * 1.32
    );
    float streamB = flameVerticalFBM(
        streamPointB + float2(28.7, -11.9),
        octaves
    );
    float fineStream = flameValueNoise(
        float2(
            normalizedPlumeX * 8.2
                + (streamA - 0.5) * 1.25
                + lateralWarp * 0.42,
            heightProgress * 1.46 - flowTime * 2.24
        )
    );

    float ridgeA = flameRidged(streamA, 7.2);
    float ridgeB = flameRidged(streamB, 8.8);
    float fineRidge = flameRidged(fineStream, 13.5);
    float flowingRidges = max(
        ridgeA * mix(0.45, 0.92, streamB),
        ridgeB * mix(0.34, 0.70, streamA)
    );
    float foldBandA = 1.0 - smoothstep(
        0.026,
        0.105,
        abs(streamA - 0.355)
    );
    float foldBandB = 1.0 - smoothstep(
        0.020,
        0.082,
        abs(streamB - 0.625)
    );
    float foldShadow = saturate(
        max(foldBandA * 0.68, foldBandB * 0.48)
    );

    float interior = smoothstep(0.32, 0.78, density);
    flowingRidges *= interior;
    foldShadow *= interior;
    float alphaTexture = 0.84
        + streamA * 0.12
        + streamB * 0.08
        + flowingRidges * 0.09
        - foldShadow * 0.15;
    float alpha = (1.0 - exp(-density * 2.55))
        * densityPresence
        * saturate(alphaTexture);
    alpha = saturate(alpha * (1.0 + flare * 0.30));

    float temperature = density * (
        0.98 - 0.73 * saturate(heightProgress)
    );
    float flareHeatLift = flare
        * densityPresence
        * (
            0.10
                + 0.22
                    * (
                        1.0
                            - smoothstep(
                                0.58,
                                1.04,
                                heightProgress
                            )
                    )
        );
    temperature += flareHeatLift;
    temperature += flowingRidges * 0.060;
    temperature -= foldShadow * 0.095;
    temperature -= (1.0 - interior) * 0.075;
    temperature = saturate(temperature);

    float hotFilament = max(
        flowingRidges * 0.75,
        fineRidge * smoothstep(0.56, 0.78, streamA) * 0.64
    );
    hotFilament *= interior;
    hotFilament *= 1.0 - smoothstep(0.64, 0.88, heightProgress);
    hotFilament = pow(saturate(hotFilament), 1.42);

    float rootCore = exp(
        -pow(
            plumeX
                / max(baseWidth * mix(0.105, 0.165, flare), 0.008),
            2.0
        )
        -pow(
            (heightProgress - mix(0.095, 0.115, flare))
                / mix(0.105, 0.145, flare),
            2.0
        )
    );
    rootCore *= smoothstep(
        mix(0.62, 0.50, flare),
        mix(0.94, 0.84, flare),
        density
    );
    rootCore *= 1.0 - smoothstep(
        mix(0.22, 0.28, flare),
        mix(0.32, 0.40, flare),
        heightProgress
    );

    float3 darkRed = float3(0.24, 0.004, 0.001);
    float3 emberRed = float3(0.61, 0.018, 0.001);
    float3 redOrange = float3(0.92, 0.060, 0.001);
    float3 strongOrange = float3(1.0, 0.16, 0.002);
    float3 deepGold = float3(1.0, 0.38, 0.006);
    float3 saturatedGold = float3(1.0, 0.66, 0.035);
    float3 filamentGold = float3(1.0, 0.76, 0.15);
    float3 whiteCore = float3(1.0, 0.90, 0.62);

    float3 flameColor = darkRed;
    flameColor = mix(
        flameColor,
        emberRed,
        smoothstep(0.055, 0.18, temperature)
    );
    flameColor = mix(
        flameColor,
        redOrange,
        smoothstep(0.15, 0.31, temperature)
    );
    flameColor = mix(
        flameColor,
        strongOrange,
        smoothstep(0.27, 0.47, temperature)
    );
    flameColor = mix(
        flameColor,
        deepGold,
        smoothstep(0.44, 0.68, temperature)
    );
    flameColor = mix(
        flameColor,
        saturatedGold,
        smoothstep(0.66, 0.90, temperature)
    );

    float tipCooling = smoothstep(0.72, 1.12, heightProgress)
        * (1.0 - temperature);
    flameColor = mix(
        flameColor,
        darkRed,
        saturate(tipCooling * 0.56)
    );
    flameColor = mix(
        flameColor,
        filamentGold,
        hotFilament * 0.76
    );
    flameColor = mix(
        flameColor,
        float3(0.60, 0.025, 0.001),
        foldShadow * (1.0 - hotFilament * 0.82) * 0.68
    );
    flameColor = mix(
        flameColor,
        whiteCore,
        rootCore * mix(0.88, 1.0, flare)
    );

    float expandedDensity = smoothstep(
        -0.105,
        0.020,
        rawDensity
    ) * rootFade;
    float halo = max(expandedDensity - densityPresence, 0.0);
    halo *= 0.095 * mix(0.84, 1.14, energy);
    float3 haloColor = mix(
        float3(0.42, 0.009, 0.001),
        float3(0.92, 0.075, 0.001),
        saturate(1.0 - heightProgress)
    );

    float rootGlow = exp(
        -pow(centeredX / max(baseWidth * 1.22, 0.02), 2.0)
        -pow((y - 0.036) / 0.055, 2.0)
    );
    rootGlow *= smoothstep(0.001, 0.022, y);
    rootGlow *= 1.0 - smoothstep(0.085, 0.145, y);
    float rootGlowAlpha = rootGlow
        * mix(0.024, 0.046, intensity)
        * (1.0 + flare * 0.72);
    float3 rootGlowColor = float3(0.92, 0.075, 0.001);

    float sparkLayerAlpha = 0.0;
    float3 sparkPremultipliedColor = float3(0.0);
    float sparkActivity = saturate(
        mix(0.25, 0.62, intensity) + flare * 0.34
    );
    sparkActivity *= mix(0.30, 1.0, motionAmount);
    float sparkMotion = mix(0.17, 1.0, motionAmount);

    for (int sparkIndex = 0; sparkIndex < 42; sparkIndex++) {
        float index = float(sparkIndex);
        float clusterIndex = floor(index / 7.0);
        float memberIndex = index - clusterIndex * 7.0;

        float clusterA = flameHash(
            float2(clusterIndex * 1.91 + 2.7, clusterIndex * 0.73 + 41.2)
        );
        float clusterB = flameHash(
            float2(clusterIndex * 0.67 + 17.4, clusterIndex * 1.43 + 6.8)
        );
        float seedA = flameHash(
            float2(index + 0.5, index * 0.618 + 12.7)
        );
        float seedB = flameHash(
            float2(index * 1.371 + 4.2, index * 0.731 + 29.1)
        );
        float4 seeds = fract(
            float4(seedA, seedB, seedA + seedB, seedA * 1.713 + seedB * 2.117)
                * float4(1.0, 1.0, 7.391, 11.173)
        );

        float cycleRate = mix(0.13, 0.28, seeds.y);
        cycleRate *= mix(0.76, 1.15, intensity);
        cycleRate *= 1.0 + flare * 0.96;
        cycleRate *= sparkMotion;
        float lifeProgress = fract(time * cycleRate + seeds.z);

        float clusterSide = fmod(clusterIndex, 2.0) < 1.0 ? -1.0 : 1.0;
        float clusterAnchorX = 0.5
            + clusterSide * baseWidth * mix(0.68, 1.34, clusterB);
        float birthX = clusterAnchorX;
        birthX += (seeds.x - 0.5) * baseWidth * 0.72;
        birthX += (memberIndex - 3.0) * baseWidth * 0.012;

        float birthY = flameHeight * mix(0.43, 0.72, clusterA);
        birthY += (seeds.y - 0.5) * flameHeight * 0.13;

        float riseCurve = lifeProgress * lifeProgress
            * (3.0 - 2.0 * lifeProgress);
        float riseDistance = mix(0.14, 0.37, intensity) + flare * 0.23;
        riseDistance *= mix(0.68, 1.21, seeds.z);
        riseDistance *= mix(0.34, 1.0, motionAmount);

        float sway = sin(
            time * mix(1.7, 4.5, seeds.z) * sparkMotion
                + clusterB * 6.2831853
                + lifeProgress * mix(1.4, 3.2, seeds.x)
        );
        sway *= mix(0.005, 0.035, seeds.w);
        sway *= 0.58 + intensity * 0.42 + flare * 0.66;
        sway *= mix(0.14, 1.0, motionAmount);
        sway *= mix(0.32, 1.0, lifeProgress);

        float outwardDrift = clusterSide
            * pow(lifeProgress, 1.34)
            * mix(0.004, 0.029, seeds.y);
        outwardDrift *= 0.54 + intensity + flare * 0.74;
        outwardDrift *= mix(0.18, 1.0, motionAmount);

        float2 sparkPosition = float2(
            birthX + sway + outwardDrift,
            birthY + riseCurve * riseDistance
        );
        float2 sparkDelta = (float2(uv.x, y) - sparkPosition) * safeSize;
        float sparkAspect = mix(0.86, 0.24, pow(seeds.y, 2.4));
        sparkDelta.y *= sparkAspect;
        float distanceToSpark = length(sparkDelta);

        float sparkRadius = mix(0.62, 3.65, pow(seeds.x, 3.35));
        sparkRadius *= mix(0.91, 1.08, intensity);
        sparkRadius *= 1.0 + flare * 0.09;
        sparkRadius *= mix(1.0, 0.48, lifeProgress);

        float sparkCore = 1.0 - smoothstep(
            sparkRadius * 0.18,
            sparkRadius,
            distanceToSpark
        );
        float sparkHalo = 1.0 - smoothstep(
            sparkRadius * 0.70,
            sparkRadius * 2.30,
            distanceToSpark
        );
        float sparkShape = saturate(sparkCore + sparkHalo * 0.13);

        float visibility = 1.0 - smoothstep(
            sparkActivity,
            sparkActivity + 0.045,
            seeds.w
        );
        float clusterPulse = 0.54 + 0.46 * sin(
            time * mix(0.7, 1.5, clusterB) * sparkMotion
                + clusterA * 6.2831853
        );
        visibility *= mix(
            0.74,
            smoothstep(0.14, 0.68, clusterPulse),
            motionAmount * 0.48
        );

        float fadeIn = smoothstep(0.0, 0.065, lifeProgress);
        float fadeOut = 1.0 - smoothstep(0.50, 1.0, lifeProgress);
        float frameFade = 1.0 - smoothstep(0.84, 0.96, sparkPosition.y);
        float sparkFlicker = 0.5 + 0.5 * sin(
            time * mix(13.0, 29.0, seeds.y) * sparkMotion
                + seeds.z * 12.566371
                + lifeProgress * 7.0
        );
        sparkFlicker = mix(
            0.96,
            mix(0.62, 1.0, sparkFlicker),
            motionAmount * 0.62
        );
        float sparkBrightness = mix(0.68, 1.0, intensity);
        sparkBrightness *= 1.0 + flare * 0.50;
        sparkBrightness *= mix(0.42, 1.0, motionAmount);

        float backgroundGate = 1.0 - smoothstep(
            0.015,
            0.25,
            density
        );
        float sparkAlpha = saturate(
            sparkShape
                * visibility
                * fadeIn
                * fadeOut
                * frameFade
                * sparkFlicker
                * sparkBrightness
                * backgroundGate
        );

        float3 sparkBirthColor = mix(
            float3(1.0, 0.25, 0.004),
            float3(1.0, 0.58, 0.055),
            seeds.x
        );
        float3 sparkMidColor = float3(1.0, 0.14, 0.002);
        float3 sparkEndColor = float3(0.40, 0.008, 0.001);
        float3 sparkColor = mix(
            sparkBirthColor,
            sparkMidColor,
            smoothstep(0.10, 0.55, lifeProgress)
        );
        sparkColor = mix(
            sparkColor,
            sparkEndColor,
            smoothstep(0.53, 0.98, lifeProgress)
        );

        sparkLayerAlpha += sparkAlpha;
        sparkPremultipliedColor += sparkColor * sparkAlpha;
    }

    float verticalBoundaryFade = smoothstep(0.0, 0.024, y)
        * (1.0 - smoothstep(0.86, 0.975, y));
    float horizontalBoundaryFade = smoothstep(0.01, 0.065, uv.x)
        * (1.0 - smoothstep(0.935, 0.99, uv.x));
    float boundaryFade = verticalBoundaryFade * horizontalBoundaryFade;
    alpha *= boundaryFade;
    halo *= boundaryFade;
    rootGlowAlpha *= boundaryFade;
    sparkLayerAlpha *= boundaryFade;
    sparkPremultipliedColor *= boundaryFade;

    float accumulatedAlpha = alpha
        + halo
        + rootGlowAlpha
        + sparkLayerAlpha;
    float combinedAlpha = saturate(accumulatedAlpha);
    float3 combinedColor = (
        flameColor * alpha
            + haloColor * halo
            + rootGlowColor * rootGlowAlpha
            + sparkPremultipliedColor
    ) / max(accumulatedAlpha, 0.0001);
    return half4(half3(combinedColor * combinedAlpha), half(combinedAlpha));
}
