CREATE TABLE Songs
(
    song_id   INT          NOT NULL PRIMARY KEY,
    name      VARCHAR(200) NOT NULL,
    text      TEXT,
    duration  INTERVAL     NOT NULL,
    album_id  INT          NOT NULL,
    artist_id INT          NOT NULL
);

CREATE TABLE Albums
(
    album_id     INT          NOT NULL PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    artist_id    INT          NOT NULL,
    song_id      INT          NOT NULL,
    release_date DATE
);

CREATE TABLE AlbumCovers
(
    album_id        INT          NOT NULL REFERENCES Albums (album_id),
    cover_path      VARCHAR(200) NOT NULL UNIQUE,
    sequence_number INT          NOT NULL,
    PRIMARY KEY (album_id, sequence_number)
);

CREATE TABLE Artists
(
    artist_id INT          NOT NULL PRIMARY KEY,
    name      VARCHAR(200) NOT NULL
);

CREATE TABLE ArtistPhotos
(
    artist_id       INT          NOT NULL REFERENCES Artists (artist_id),
    photo_path      VARCHAR(200) NOT NULL UNIQUE,
    sequence_number INT          NOT NULL,
    PRIMARY KEY (artist_id, sequence_number)
);

CREATE TABLE AlbumAuthors
(
    album_id  INT NOT NULL REFERENCES Albums (album_id),
    artist_id INT NOT NULL REFERENCES Artists (artist_id),
    PRIMARY KEY (album_id, artist_id)
);

ALTER TABLE Albums
    ADD FOREIGN KEY (album_id, artist_id)
        REFERENCES AlbumAuthors (album_id, artist_id) DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE SongInAlbums
(
    song_id  INT      NOT NULL REFERENCES Songs (song_id),
    album_id INT      NOT NULL REFERENCES Albums (album_id),
    position SMALLINT NOT NULL,
    PRIMARY KEY (album_id, song_id),
    UNIQUE (album_id, position)
);

ALTER TABLE Albums
    ADD FOREIGN KEY (album_id, song_id)
        REFERENCES SongInAlbums (album_id, song_id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE Songs
    ADD FOREIGN KEY (album_id, song_id)
        REFERENCES SongInAlbums (album_id, song_id) DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE SongAuthors
(
    song_id   INT NOT NULL REFERENCES Songs (song_id),
    artist_id INT NOT NULL REFERENCES Artists (artist_id),
    PRIMARY KEY (song_id, artist_id)
);

ALTER TABLE Songs
    ADD FOREIGN KEY (song_id, artist_id)
        REFERENCES SongAuthors (song_id, artist_id) DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE Users
(
    user_id             INT          NOT NULL PRIMARY KEY,
    login               VARCHAR(100) NOT NULL UNIQUE,
    pass_hash_with_salt TEXT         NOT NULL
);

CREATE TABLE UserAvatars
(
    user_id         INT          NOT NULL REFERENCES Users (user_id),
    avatar_path     VARCHAR(200) NOT NULL UNIQUE,
    sequence_number INT          NOT NULL,
    PRIMARY KEY (user_id, sequence_number)
);

CREATE TABLE AlbumRatings
(
    album_id INT        NOT NULL REFERENCES Albums (album_id),
    user_id  INT        NOT NULL REFERENCES Users (user_id),
    rating   DECIMAL(1) NOT NULL
        CONSTRAINT correct_song_rating CHECK (rating >= 1 AND rating <= 5),
    PRIMARY KEY (album_id, user_id)
);

CREATE TABLE SongRatings
(
    song_id INT        NOT NULL REFERENCES Songs (song_id),
    user_id INT        NOT NULL REFERENCES Users (user_id),
    rating  DECIMAL(1) NOT NULL
        CONSTRAINT correct_song_rating CHECK (rating >= 1 AND rating <= 5),
    PRIMARY KEY (song_id, user_id)
);

CREATE TABLE Playlists
(
    playlist_id INT          NOT NULL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    owner_id    INT          NOT NULL REFERENCES Users (user_id)
);

CREATE TABLE SongInPlaylists
(
    playlist_id INT      NOT NULL REFERENCES Playlists (playlist_id),
    song_id     INT      NOT NULL REFERENCES Songs (song_id),
    position    SMALLINT NOT NULL,
    PRIMARY KEY (playlist_id, position)
);