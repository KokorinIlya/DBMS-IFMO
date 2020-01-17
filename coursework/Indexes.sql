CREATE UNIQUE INDEX user_login_idx ON Users (login);

CREATE INDEX song_names_idx
    ON Songs USING btree (name, song_id);

CREATE INDEX user_avatars_position_idx
    ON UserAvatars USING btree (user_id, sequence_number);

CREATE INDEX song_in_playlist_position_idx
    ON SongInPlaylists USING btree (playlist_id, position, song_id);

CREATE INDEX album_ratings_by_album_idx
    ON AlbumRatings USING btree (album_id, user_id, rating);

CREATE INDEX album_ratings_by_user_idx
    ON AlbumRatings USING btree (user_id, album_id, rating);

CREATE INDEX song_ratings_by_song_idx
    ON SongRatings USING btree (song_id, user_id, rating);

CREATE INDEX song_ratings_by_user_idx
    ON SongRatings USING btree (user_id, song_id, rating);

CREATE INDEX artist_photos_position_idx
    ON ArtistPhotos USING btree (artist_id, sequence_number);

CREATE INDEX album_covers_position_idx
    ON AlbumCovers USING btree (album_id, sequence_number);

CREATE INDEX song_in_albums_by_album_idx
    ON SongInAlbums USING btree (album_id, position, song_id);

CREATE INDEX song_in_albums_by_song_idx
    ON SongInAlbums USING btree (song_id, album_id);

CREATE INDEX album_authors_by_album_idx
    ON AlbumAuthors USING btree (album_id, artist_id);

CREATE INDEX album_authors_by_artist_idx
    ON AlbumAuthors USING btree (artist_id, album_id);

CREATE INDEX song_authors_by_song_idx
    ON SongAuthors USING btree (song_id, artist_id);

CREATE INDEX song_authors_by_artist_idx
    ON SongAuthors USING btree (artist_id, song_id);