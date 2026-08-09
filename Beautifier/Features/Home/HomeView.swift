import SwiftUI
import PhotosUI

struct HomeView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingEditView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "photo.on.rectangle.angled")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.secondary)

                Text("Pick a Photo")
                    .font(.title2)
                    .foregroundStyle(.primary)

                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Choose from Library")
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    loadDemoPhoto(resourceName: "test_face")
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("Try Demo Photo")
                            .foregroundStyle(.purple)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("TryDemoPhoto")

                Button {
                    loadSyntheticNoFacePhoto()
                } label: {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(.orange)
                        Text("Try Demo (No Face)")
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("TryDemoNoFacePhoto")
            }
            .padding()
            .navigationTitle("Beautify")
            .navigationDestination(isPresented: $showingEditView) {
                if let data = selectedImageData {
                    EditView(originalData: data)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        showingEditView = true
                    }
                    pickerItem = nil
                }
            }
        }
    }

    private func loadDemoPhoto(resourceName: String) {
        let loadedData = Bundle.main.url(forResource: resourceName, withExtension: "jpg")
            .flatMap { try? Data(contentsOf: $0) }
            ?? Bundle.main.url(forResource: "sample_face", withExtension: "jpg")
            .flatMap { try? Data(contentsOf: $0) }
            ?? UIImage(named: resourceName)?.jpegData(compressionQuality: 0.9)
            ?? UIImage(named: "sample_face")?.jpegData(compressionQuality: 0.9)

        if let loadedData {
            selectedImageData = loadedData
            showingEditView = true
        }
    }

    private func loadSyntheticNoFacePhoto() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500))
        let img = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 300, height: 300))
        }
        selectedImageData = img.jpegData(compressionQuality: 0.9)
        showingEditView = true
    }
}
