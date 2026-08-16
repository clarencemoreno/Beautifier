# Design — Semantic Skin Parser

## 1. The model

BiSeNet (from `zllrunning/face-parsing.PyTorch`), pretrained on
CelebAMask-HQ, 19 classes. We wrap it so the Core ML model outputs ONLY the
softmax probability of the skin class, with ImageNet normalization baked in.
Input: 512×512 RGB in [0,1]. Output: 512×512 grayscale probability map.

## 2. One-time conversion script (run on a laptop, ~5 min, no training)

```bash
git clone https://github.com/zllrunning/face-parsing.PyTorch.git
cd face-parsing.PyTorch
pip install torch torchvision coremltools pillow
# Download 79999_iter.pth from the link in the repo README, place it here.
```

```python
# convert_skin_parser.py  (run inside the cloned repo)
import torch, coremltools as ct
from model import BiSeNet
from PIL import Image
import torchvision.transforms.functional as TF

SKIN_INDEX = 1   # VERIFY in step 3; CelebAMask-HQ ordering in this repo

class SkinNet(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.net = BiSeNet(n_classes=19)
        self.mean = torch.tensor([0.485, 0.456, 0.606]).view(1, 3, 1, 1)
        self.std  = torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1)

    def forward(self, x):                      # x in [0, 1]
        x = (x - self.mean) / self.std
        logits = self.net(x)[0]
        return torch.softmax(logits, dim=1)[:, SKIN_INDEX:SKIN_INDEX+1, :, :]

model = SkinNet()
model.net.load_state_dict(torch.load("79999_iter.pth", map_location="cpu"))
model.eval()

# --- MANDATORY visual verification BEFORE converting ---
img = TF.to_tensor(Image.open("test_face.jpg").convert("RGB").resize((512, 512)))
with torch.no_grad():
    mask = model(img.unsqueeze(0))[0, 0]
TF.to_pil_image(mask).save("verify_mask.png")
# OPEN verify_mask.png: face skin must be WHITE; eyes/brows/lips/hair/
# background BLACK. If wrong, loop SKIN_INDEX 0..18 and re-save until correct.

traced = torch.jit.trace(model, torch.randn(1, 3, 512, 512))
ml = ct.convert(
    traced,
    inputs=[ct.ImageType(name="image", shape=(1, 3, 512, 512),
                         scale=1/255.0, bias=0.0)],
    outputs=[ct.ImageType(name="skinMask")],
    compute_units=ct.ComputeUnit.ALL,
)
ml.save("FaceParserSkin.mlpackage")
```

Drag `FaceParserSkin.mlpackage` into the Xcode project (it generates a
`FaceParserSkin` Swift class automatically).

## 3. Swift integration

```swift
// Core/ML/SkinParserML.swift
import Vision
import CoreML

enum SkinParserML {
    private static let request: VNCoreMLRequest = {
        let config = MLModelConfiguration()
        config.computeUnits = .all          // ANE on device, CPU on Simulator
        let model = try! FaceParserSkin(configuration: config).model
        let req = try! VNCoreMLRequest(model: model)
        req.imageCropAndScaleOption = .scaleFill   // center-crop to 512×512
        return req
    }()

    /// Grayscale skin-probability mask at model resolution (512×512).
    static func skinMask(for cgImage: CGImage) -> CIImage? {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNPixelBufferObservation
        else { return nil }
        return CIImage(cvPixelBuffer: obs.pixelBuffer)
    }
}
```

## 4. Mask assembly (replaces ALL previous mask logic)

```swift
// SkinMaskBuilder — new, minimal
static func buildMask(for image: CIImage, skinMask: CIImage) -> CIImage {
    let sx = image.extent.width  / skinMask.extent.width
    let sy = image.extent.height / skinMask.extent.height
    return skinMask
        .transformed(by: .init(scaleX: sx, y: sy))
        .clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3])
        .cropped(to: image.extent)
}
```

No rectangles. No color thresholds. No ellipse. The model's skin class
already excludes eyes, brows, lips, hair, clothing, and background.

## 5. Radius clamp (the blob fix)

```swift
// In performRender() and save():
let maxRadius = 15.0 * image.extent.width / 2048.0   // scales with resolution
let radius = min(max(faceWidthPx * 0.04, 4.0 * image.extent.width / 2048.0), maxRadius)
```

## 6. No-face gating

If the ML mask's mean luminance ≈ 0 (no skin pixels), treat as no face:
slider disabled. `FaceDetector` remains ONLY for the debug overlay and
face-width radius sizing.

## 7. Risks

| Risk | Response |
|------|----------|
| Wrong SKIN_INDEX after conversion | Mandatory verify_mask.png step catches it before conversion. |
| 512×512 mask edges slightly soft on 4K saves | Acceptable; feather blur hides it. Upgrade path: run model at 1024. |
| Simulator latency | CPU inference at 512×512 is ~100–300ms — fine, it's cached per photo. |
