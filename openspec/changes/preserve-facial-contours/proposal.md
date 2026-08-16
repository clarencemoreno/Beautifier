# Change: Edge-Preserving Skin Smoothing and Facial Contour Preservation (Week 4.5)

## Why

While semantic skin segmentation successfully isolates skin regions, the current smoothing filter uses an isotropic Gaussian blur (`CIGaussianBlur`). Gaussian blur averages all pixels within its radius indiscriminately of local contrast or gradient boundaries.

As a result:
- **Facial lines and 3D contours fade**: The jawline silhouette, nose bridge shadows, nostril contours, eyelid folds, and eye sockets lose sharpness and depth, resulting in a flat, artificial "plastic/airbrushed" look.
- **Structural facial depth is compromised**: Distinct facial features should retain crisp, sharp definition while micro-surface skin blemishes, pores, and tone redness are softened.

## What Changes

1. **Edge-Aware Smoothing Pipeline (`Core/Filters/SmoothingFilter.swift`)**:
   - Upgrade from isotropic Gaussian blur to a **Frequency-Separated / Edge-Aware Smoothing Filter**.
   - Decomposes the image into low-frequency color/tone base and high-frequency structural edge texture.
   - Softens low/medium frequency skin tone imperfections while preserving high-contrast facial contours and feature boundaries.

2. **Structural Edge Suppression in Skin Mask (`Core/Filters/SkinMaskBuilder.swift`)**:
   - Integrates luminance edge gradient detection (`CIEdges` / Sobel gradient attenuation) to automatically protect sharp facial boundaries (jawline, nose ridge, nostril creases, philtrum) from excessive blur.

3. **Fine-Tuned Radius & Edge-Preservation Controls**:
   - Calibrates smoothing radius and edge-preservation weight to maintain natural facial contours across both the 60fps live camera preview and high-resolution photo saves.

## Impact

- **Affected specs**: `image-editing` and `camera` capabilities.
- **Performance**: Remains 100% GPU-accelerated via Core Image / Metal pipelines, maintaining 60fps real-time camera rendering.
