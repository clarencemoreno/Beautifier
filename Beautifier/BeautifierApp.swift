//
//  BeautifierApp.swift
//  Beautifier
//
//  Created by ClyCesBon on 8/1/26.
//

import SwiftUI

@main
struct BeautifierApp: App {
    private var demoImageData: Data? {
        Bundle.main.url(forResource: "test_face", withExtension: "jpg")
            .flatMap { try? Data(contentsOf: $0) }
            ?? Bundle.main.url(forResource: "sample_face", withExtension: "jpg")
            .flatMap { try? Data(contentsOf: $0) }
            ?? UIImage(named: "test_face")?.jpegData(compressionQuality: 0.9)
            ?? UIImage(named: "sample_face")?.jpegData(compressionQuality: 0.9)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if let data = demoImageData {
                    EditView(originalData: data)
                } else {
                    HomeView()
                }
            }
        }
    }
}
