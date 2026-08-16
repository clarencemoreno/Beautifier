import Foundation

/// Runtime feature flags for optional pipeline switches.
enum FeatureFlags {

    /// When `true`, the edit pipeline uses the BiSeNet Core ML semantic
    /// skin parser (`SkinParserML`) instead of the legacy
    /// `FaceSegmenter` (person segmentation + ellipse fallback).
    ///
    /// Default is `true` in DEBUG builds; flip to `false` to exercise the
    /// old pipeline side-by-side for comparison.
    static var semanticSkinParser: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
