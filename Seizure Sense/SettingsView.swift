//
//  SettingsView.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//
//
import SwiftUI

struct SettingsView: View {
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color now fully theme-safe
                settings.theme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16 * settings.textScale) {
                        
                        // MARK: Appearance & Text Size
                        VStack(spacing: 16 * settings.textScale) {
                            
                            // Appearance
                            VStack(alignment: .leading, spacing: 8 * settings.textScale) {
                                Text("Appearance")
                                    .font(.system(size: 20 * settings.textScale, weight: .bold))
                                    .foregroundColor(settings.theme.foregroundColor)
                                
                                Picker("Appearance", selection: $settings.theme) {
                                    ForEach(Theme.allCases) { theme in
                                        Text(theme.rawValue.capitalized).tag(theme)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12 * settings.textScale)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(settings.theme.secondaryColor.opacity(0.3))
                            )
                            
                            // Text Size
                            VStack(alignment: .leading, spacing: 8 * settings.textScale) {
                                Text("Text Size")
                                    .font(.system(size: 20 * settings.textScale, weight: .bold))
                                    .foregroundColor(settings.theme.foregroundColor)
                                
                                HStack {
                                    Text("A").font(.system(size: 12 * settings.textScale))
                                    Slider(value: $settings.textScale, in: 0.8...1.6, step: 0.05)
                                    Text("A").font(.system(size: 24 * settings.textScale))
                                }
                            }
                            .padding(12 * settings.textScale)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(settings.theme.secondaryColor.opacity(0.3))
                            )
                        }
                        .padding(.horizontal)
                        
                        // MARK: Buttons Section
                        VStack(spacing: 12 * settings.textScale) {
                            // settingsButton(title: "Messaging", icon: "message") { MessagingView() }
                            settingsButton(title: "Threshold Settings", icon: "slider.horizontal.3") { ThresholdViewBlue() }
                            
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.top)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(settings.theme.foregroundColor)
                    }
                }
            }
        }
        // Fully respects the selected theme
        .preferredColorScheme(
            settings.theme == .light ? .light :
            settings.theme == .dark ? .dark : nil
        )
    }
    
    // MARK: - Reusable Button
    func settingsButton<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination().environmentObject(settings)) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18 * settings.textScale))
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 17 * settings.textScale, weight: .medium))
                    .foregroundColor(settings.theme.foregroundColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(10 * settings.textScale)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.theme.secondaryColor.opacity(0.3))
            )
        }
    }
}

// MARK: Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppSettings())
    }
}


