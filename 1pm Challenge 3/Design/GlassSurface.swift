//
//  GlassSurface.swift
//  1pm Challenge 3
//

import SwiftUI

extension View {
    /// Wraps the view in the system Liquid Glass material on iOS 26 and later.
    /// Because this is the real system material, it follows the iPhone's
    /// Liquid Glass appearance preference (Clear or Tinted) as well as
    /// Reduce Transparency, instead of using a fixed custom blur on them.
    @ViewBuilder
    func adaptiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }
}
