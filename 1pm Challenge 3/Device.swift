////
////  Device.swift
////  1pm Challenge 3
////
////  Created by Nishika Agrawal on 12/11/26.
////
//
//
//import SwiftUI
//
//// MARK: - Storage Data
//
//struct StorageSegment: Identifiable {
//    let id = UUID()
//    let name: String
//    let percentage: Double
//    let color: Color
//}
//
//// MARK: - Screen 1: Storage Breakdown
//
//struct StorageDetailView: View {
//
//    let segments = [
//        StorageSegment(name: "Photos", percentage: 0.42, color: .blue),
//        StorageSegment(name: "Videos", percentage: 0.35, color: .purple),
//        StorageSegment(name: "Files", percentage: 0.23, color: .orange)
//    ]
//
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 25) {
//
//                // Header
//                HStack {
//                    Text("Storage Details")
//                        .font(.largeTitle)
//                        .bold()
//
//                    Spacer()
//
//                    Image(systemName: "ellipsis.circle")
//                        .font(.title2)
//                }
//                .padding(.horizontal)
//
//                Text("Your storage breakdown")
//                    .font(.headline)
//                    .foregroundStyle(.secondary)
//
//                // Circular storage chart
//                ZStack {
//                    Circle()
//                        .stroke(
//                            Color.gray.opacity(0.15),
//                            lineWidth: 25
//                        )
//
//                    ForEach(segments.indices, id: \.self) { index in
//                        let segment = segments[index]
//
//                        let start = segments.prefix(index)
//                            .reduce(0.0) {
//                                $0 + $1.percentage
//                            }
//
//                        Circle()
//                            .trim(
//                                from: start,
//                                to: start + segment.percentage
//                            )
//                            .stroke(
//                                segment.color,
//                                style: StrokeStyle(
//                                    lineWidth: 25,
//                                    lineCap: .butt
//                                )
//                            )
//                            .rotationEffect(.degrees(-90))
//                    }
//
//                    VStack(spacing: 5) {
//                        Text("Photos")
//                            .font(.headline)
//
//                        Text("42%")
//                            .font(.system(size: 32, weight: .bold))
//
//                        Text("of selected storage")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//                .frame(width: 230, height: 230)
//                .padding()
//
//                // Storage category legend
//                VStack(spacing: 15) {
//                    ForEach(segments) { segment in
//                        HStack {
//                            Circle()
//                                .fill(segment.color)
//                                .frame(width: 12, height: 12)
//
//                            Text(segment.name)
//
//                            Spacer()
//
//                            Text("\(Int(segment.percentage * 100))%")
//                                .bold()
//                        }
//                    }
//                }
//                .padding(.horizontal, 35)
//
//                Spacer()
//
//                // Navigate to screenshot gallery
//                NavigationLink {
//                    ScreenshotGalleryView()
//                } label: {
//                    HStack {
//                        Image(systemName: "photo.on.rectangle")
//
//                        Text("View Screenshots")
//
//                        Spacer()
//
//                        Image(systemName: "chevron.right")
//                    }
//                    .font(.headline)
//                    .padding()
//                    .background(Color.blue.opacity(0.12))
//                    .foregroundStyle(.blue)
//                    .clipShape(
//                        RoundedRectangle(cornerRadius: 15)
//                    )
//                }
//                .padding(.horizontal)
//            }
//            .padding(.top)
//        }
//    }
//}
//
//// MARK: - Screenshot Sample Data
//
//struct ScreenshotItem: Identifiable {
//    let id: String
//    let date: String
//    let size: String
//    let category: ScreenshotCategory
//}
//
//enum ScreenshotCategory: String, CaseIterable {
//    case old = "Old"
//    case large = "Large"
//    case duplicate = "Duplicates"
//}
//
//// MARK: - Screen 2: Screenshot Gallery
//
//struct ScreenshotGalleryView: View {
//
//    @State private var selectedFilter = "All"
//    @State private var selectedItems: Set<String> = []
//
//    let filters = [
//        "All",
//        "Old",
//        "Large",
//        "Duplicates"
//    ]
//
//    let screenshots = [
//        ScreenshotItem(
//            id: "1",
//            date: "12 Oct 2026",
//            size: "2.4 MB",
//            category: .old
//        ),
//        ScreenshotItem(
//            id: "2",
//            date: "20 Oct 2026",
//            size: "5.1 MB",
//            category: .large
//        ),
//        ScreenshotItem(
//            id: "3",
//            date: "25 Oct 2026",
//            size: "3.2 MB",
//            category: .duplicate
//        ),
//        ScreenshotItem(
//            id: "4",
//            date: "28 Oct 2026",
//            size: "1.8 MB",
//            category: .old
//        ),
//        ScreenshotItem(
//            id: "5",
//            date: "30 Oct 2026",
//            size: "4.6 MB",
//            category: .large
//        ),
//        ScreenshotItem(
//            id: "6",
//            date: "2 Nov 2026",
//            size: "2.1 MB",
//            category: .duplicate
//        )
//    ]
//
//    var filteredScreenshots: [ScreenshotItem] {
//        if selectedFilter == "All" {
//            return screenshots
//        }
//
//        return screenshots.filter {
//            $0.category.rawValue == selectedFilter
//        }
//    }
//
//    var body: some View {
//        VStack(spacing: 20) {
//
//            // Header
//            HStack {
//                VStack(alignment: .leading, spacing: 5) {
//                    Text("Screenshots")
//                        .font(.largeTitle)
//                        .bold()
//
//                    Text("Manage your screenshot storage")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                }
//
//                Spacer()
//
//                Image(systemName: "slider.horizontal.3")
//                    .font(.title2)
//            }
//            .padding(.horizontal)
//
//            // Filter buttons
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 10) {
//                    ForEach(filters, id: \.self) { filter in
//
//                        Button {
//                            selectedFilter = filter
//                        } label: {
//                            Text(filter)
//                                .font(.subheadline)
//                                .bold()
//                                .padding(.horizontal, 18)
//                                .padding(.vertical, 10)
//                                .background(
//                                    selectedFilter == filter
//                                    ? Color.blue
//                                    : Color.gray.opacity(0.15)
//                                )
//                                .foregroundStyle(
//                                    selectedFilter == filter
//                                    ? .white
//                                    : .primary
//                                )
//                                .clipShape(Capsule())
//                        }
//                    }
//                }
//                .padding(.horizontal)
//            }
//
//            // Screenshot grid
//            ScrollView {
//                LazyVGrid(
//                    columns: [
//                        GridItem(.flexible()),
//                        GridItem(.flexible()),
//                        GridItem(.flexible())
//                    ],
//                    spacing: 15
//                ) {
//
//                    ForEach(filteredScreenshots) { item in
//
//                        Button {
//                            if selectedItems.contains(item.id) {
//                                selectedItems.remove(item.id)
//                            } else {
//                                selectedItems.insert(item.id)
//                            }
//                        } label: {
//
//                            VStack(alignment: .leading, spacing: 7) {
//
//                                ZStack(alignment: .topTrailing) {
//
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(Color.blue.opacity(0.10))
//                                        .frame(height: 115)
//                                        .overlay {
//                                            Image(systemName: "photo")
//                                                .font(.system(size: 35))
//                                                .foregroundStyle(.blue)
//                                        }
//
//                                    if selectedItems.contains(item.id) {
//                                        Image(
//                                            systemName: "checkmark.circle.fill"
//                                        )
//                                        .foregroundStyle(.blue)
//                                        .padding(6)
//                                    }
//                                }
//                                .overlay {
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .stroke(
//                                            selectedItems.contains(item.id)
//                                            ? Color.blue
//                                            : Color.clear,
//                                            lineWidth: 3
//                                        )
//                                }
//
//                                Text(item.date)
//                                    .font(.caption2)
//                                    .lineLimit(1)
//
//                                Text(item.size)
//                                    .font(.caption)
//                                    .bold()
//                                    .foregroundStyle(.secondary)
//                            }
//                            .foregroundStyle(.primary)
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//                .padding(.horizontal)
//            }
//
//            // Selection information
//            if !selectedItems.isEmpty {
//
//                HStack {
//                    Text("\(selectedItems.count) selected")
//                        .bold()
//
//                    Spacer()
//
//                    Button("Clear selection") {
//                        selectedItems.removeAll()
//                    }
//                    .foregroundStyle(.blue)
//                }
//                .padding()
//            }
//        }
//        .padding(.top)
//    }
//}
//
//// MARK: - Preview
//
//#Preview {
//    StorageDetailView()
//}
