//
//  ThresholdViewBlue.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//

import SwiftUI

struct ThresholdViewBlue: View {
    @EnvironmentObject var settings: AppSettings

    enum HRMode: String, CaseIterable, Identifiable {
        case adaptive = "Adaptive Thresholding"
        case nonAdaptive = "Non-Adaptive Thresholding"
        var id: String { rawValue }
    }

    @State private var selectedHRMode: HRMode = .adaptive
    @AppStorage("baselineHR") private var baselineHR: Int = 70
    @State private var showBaselineInfo = false

    // Info sheet toggles
    @State private var showHRInfo = false
    @State private var showMovementInfo = false

    @FocusState private var baselineFieldFocused: Bool

    private var intFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Light blue background, adapts for dark mode
                (settings.theme == .light
                 ? Color(red: 0.85, green: 0.93, blue: 1.0)
                 : Color(red: 0.1, green: 0.12, blue: 0.18))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20 * settings.textScale) {

                        Spacer().frame(height: 20)

                        // ----------------------------
                        // BASELINE HR BOX
                        // ----------------------------
                        VStack(alignment: .leading, spacing: 15 * settings.textScale) {
                            HStack {
                                Text("Baseline Threshold")
                                    .font(.system(size: 20 * settings.textScale, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button {
                                    showBaselineInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20 * settings.textScale))
                                }
                            }

                            HStack {
                                Text("Heart Rate (bpm)")
                                    .font(.system(size: 16 * settings.textScale))
                                TextField("Baseline", value: $baselineHR, formatter: intFormatter)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .focused($baselineFieldFocused)
                                    .submitLabel(.done)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(settings.theme == .light ? Color.white : Color(.systemGray6))
                        )
                        .shadow(radius: 2)
                        .sheet(isPresented: $showBaselineInfo) {
                            VStack(spacing: 20) {
                                Text("Baseline Threshold")
                                    .font(.title2)
                                    .bold()
                                Text("This value sets the absolute heart rate threshold used by detection. When your heart rate reaches or exceeds this number at the same time as a motion spike, the app will consider it a potential seizure event.")
                                    .padding()
                                Text("Tip: Choose a value that's appropriately above your resting heart rate, but low enough to catch significant rises.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Button("Close") { showBaselineInfo = false }
                                    .padding(.top, 10)
                            }
                            .padding()
                            .presentationDetents([.medium])
                        }

                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Threshold Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        baselineFieldFocused = false
                    }
                }
            }
        }
        .preferredColorScheme(settings.theme == .light ? .light : .dark)
    }
}

#Preview {
    ThresholdViewBlue()
        .environmentObject(AppSettings())
}

