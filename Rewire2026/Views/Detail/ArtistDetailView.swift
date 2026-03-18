import SwiftUI
import SwiftData

struct ArtistDetailView: View {
    let slot: Slot

    @EnvironmentObject var store: ArtistStore
    @Environment(\.modelContext) private var modelContext
    @Query private var allUserData: [UserArtistData]
    @State private var notesText = ""
    @FocusState private var notesFocused: Bool

    private var participants: [Artist] {
        slot.artistIds.compactMap { store.lineup.artists[$0] }
    }

    private var userData: UserArtistData? {
        allUserData.first { $0.artistId == slot.id }
    }

    private func getOrCreate() -> UserArtistData {
        if let existing = userData { return existing }
        let new = UserArtistData(artistId: slot.id)
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        HStack(spacing: 6) {
                            WaveBadge(wave: slot.wave)
                            if slot.isWorldPremiere { WorldPremiereBadge() }
                            if let type = slot.performanceType { TypeBadge(type: type) }
                            if slot.requiresPlusTicket {
                                Image(systemName: "ticket")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.rewireTertiary)
                            }
                        }
                        Spacer()
                        Button {
                            let data = getOrCreate()
                            data.isBookmarked.toggle()
                        } label: {
                            Image(systemName: userData?.isBookmarked == true ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 22))
                                .foregroundStyle(userData?.isBookmarked == true ? Color.rewireAccent : Color.rewireMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(slot.displayName)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.rewireText)

                    if let project = slot.project, !project.isEmpty {
                        Text(project)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                    }
                }
                .padding(16)

                dividerLine

                // ── Must See Rating ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("MUST SEE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.rewireMuted)
                    MustSeeRatingView(rating: userData?.mustSeeRating ?? 0) { newRating in
                        getOrCreate().mustSeeRating = newRating
                    }
                }
                .padding(16)

                dividerLine

                // ── Collab info (if collab) ──────────────────────────────
                if slot.isCollab {
                    if let notes = slot.collabNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.rewireText)
                            .lineSpacing(5)
                            .padding(16)
                    }
                    if slot.collabLatest != nil || slot.collabTopRated != nil {
                        VStack(alignment: .leading, spacing: 14) {
                            if let rel = slot.collabLatest {
                                ReleaseRow(label: "COLLAB LATEST", release: rel)
                            }
                            if let rel = slot.collabTopRated {
                                ReleaseRow(label: "COLLAB TOP RATED", release: rel)
                            }
                        }
                        .padding(16)
                    }
                    dividerLine
                }

                // ── Participants ─────────────────────────────────────────
                ForEach(Array(participants.enumerated()), id: \.offset) { _, artist in
                    ParticipantSection(artist: artist, showDivider: true)
                }

                // ── Conflict Warning (once timetable data exists) ─────────────────
                let conflictingSlots = store.conflicts(for: slot, allUserData: allUserData)
                if !conflictingSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.rewireTertiary)
                            Text("SCHEDULE CONFLICT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.rewireTertiary)
                        }
                        ForEach(conflictingSlots, id: \.id) { conflict in
                            HStack(spacing: 4) {
                                Text("•").foregroundStyle(Color.rewireTertiary)
                                Text(conflict.displayName)
                                if let t = conflict.time {
                                    Text("· \(t)").foregroundStyle(Color.rewireMuted)
                                }
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.rewireText)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rewireTertiary.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.rewireTertiary.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    dividerLine
                }

                // ── Plus Ticket Warning ──────────────────────────────────
                if slot.requiresPlusTicket {
                    PlusTicketWarning()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    dividerLine
                }

                // ── Timetable ────────────────────────────────────────────
                if slot.day != nil || slot.time != nil || slot.stage != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCHEDULE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                        HStack(spacing: 12) {
                            if let day = slot.day {
                                Label(day, systemImage: "calendar")
                            }
                            if let time = slot.time {
                                Label(time, systemImage: "clock")
                            }
                            if let stage = slot.stage {
                                Label(stage, systemImage: "mappin")
                            }
                        }
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.rewireText)
                    }
                    .padding(16)
                    dividerLine
                }

                // ── Personal Notes ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERSONAL NOTES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.rewireMuted)

                    TextEditor(text: $notesText)
                        .focused($notesFocused)
                        .scrollContentBackground(.hidden)
                        .background(Color.rewireSurface)
                        .foregroundStyle(Color.rewireText)
                        .font(.system(size: 14))
                        .frame(minHeight: 100)
                        .padding(10)
                        .overlay(Rectangle().stroke(notesFocused ? Color.rewireAccent : Color.rewireBorder, lineWidth: 1))
                        .onChange(of: notesText) { _, new in
                            let current = userData?.personalNotes ?? ""
                            if new != current { getOrCreate().personalNotes = new }
                        }

                    if notesFocused {
                        Button("Done") { notesFocused = false }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.rewireAccent)
                    }
                }
                .padding(16)
            }
        }
        .background(Color.rewireBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.rewireSurface, for: .navigationBar)
        .onAppear { notesText = userData?.personalNotes ?? "" }
    }

    private var dividerLine: some View {
        Rectangle().fill(Color.rewireBorder).frame(height: 1)
    }
}

// MARK: - Participant section (one artist's profile block)

private struct ParticipantSection: View {
    let artist: Artist
    let showDivider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image (full-width, no side padding)
            if let imageUrl = artist.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    case .empty:
                        Rectangle()
                            .fill(Color.rewireSurface)
                            .frame(height: 200)
                            .overlay(ProgressView().tint(Color.rewireMuted))
                    default:
                        EmptyView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
            Text(artist.name)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.rewireText)

            if !artist.genreList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(artist.genreList, id: \.self) { GenreTag(text: $0) }
                    }
                }
            }

            if let notes = artist.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.rewireMuted)
                    .lineSpacing(4)
            }

            if artist.latest != nil || artist.topRated != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let rel = artist.latest   { ReleaseRow(label: "LATEST",     release: rel) }
                    if let rel = artist.topRated { ReleaseRow(label: "TOP RATED",  release: rel) }
                }
            }
        }
        .padding(16)

        if showDivider {
            Rectangle().fill(Color.rewireBorder).frame(height: 1)
        }
        } // outer VStack
    }
}
