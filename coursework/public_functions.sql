-- Read Commited
CREATE OR REPLACE FUNCTION create_user(user_id_arg INT,
                                       login_arg VARCHAR(100),
                                       pass_arg TEXT) RETURNS BOOLEAN AS
$$
DECLARE
    pass_hash       TEXT;
    new_users_count INT;
BEGIN
    pass_hash := crypt(pass_arg, gen_salt('bf', 8));

    INSERT INTO Users (user_id, login, pass_hash_with_salt)
    VALUES (user_id_arg, login_arg, pass_hash)
    ON CONFLICT (user_id) DO NOTHING;

    GET DIAGNOSTICS new_users_count = ROW_COUNT;
    RETURN new_users_count = 1;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION add_user_avatar(login_arg VARCHAR(100),
                                           pass_arg TEXT,
                                           avatar_path_arg VARCHAR(200)) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user            Users := check_credentials(login_arg, pass_arg);
    new_photos_count    INT;
    max_sequence_number INT;
    prev_max_number     INT   := -1;
BEGIN
    IF cur_user IS NOT NULL THEN
        LOOP
            max_sequence_number := (SELECT coalesce(max(UserAvatars.sequence_number), 0)
                                    FROM UserAvatars
                                    WHERE UserAvatars.user_id = cur_user.user_id);
            IF prev_max_number = max_sequence_number THEN
                RETURN FALSE;
            END IF;
            prev_max_number := max_sequence_number;

            INSERT INTO UserAvatars (user_id, avatar_path, sequence_number)
            VALUES (cur_user.user_id, avatar_path_arg, max_sequence_number + 1)
            ON CONFLICT (user_id, sequence_number) DO NOTHING;

            GET DIAGNOSTICS new_photos_count = ROW_COUNT;

            IF new_photos_count = 1 THEN
                RETURN TRUE;
            END IF;
        END LOOP;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION delete_user_avatar(login_arg VARCHAR(100),
                                              pass_arg TEXT,
                                              avatar_number INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user        Users := check_credentials(login_arg, pass_arg);
    deleted_avatars INT;
BEGIN
    IF cur_user IS NOT NULL THEN
        DELETE
        FROM UserAvatars
        WHERE UserAvatars.user_id = cur_user.user_id
          AND UserAvatars.sequence_number = avatar_number;

        GET DIAGNOSTICS deleted_avatars = ROW_COUNT;
        RETURN deleted_avatars = 1;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION add_user_playlist(login_arg VARCHAR(100),
                                             pass_arg TEXT,
                                             playlist_id_arg INT,
                                             playlist_name_arg VARCHAR(200)) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user            Users := check_credentials(login_arg, pass_arg);
    new_playlists_count INT;
BEGIN
    IF cur_user IS NOT NULL THEN
        INSERT INTO Playlists (playlist_id, name, owner_id)
        VALUES (playlist_id_arg, playlist_name_arg, cur_user.user_id)
        ON CONFLICT (playlist_id) DO NOTHING;

        GET DIAGNOSTICS new_playlists_count = ROW_COUNT;

        RETURN new_playlists_count = 1;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION add_song_to_playlist(login_arg VARCHAR(100),
                                                pass_arg TEXT,
                                                playlist_id_arg INT,
                                                song_id_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user           Users := check_credentials(login_arg, pass_arg);
    last_position      INT;
    inserted_songs     INT;
    prev_last_position INT   := -1;
BEGIN
    IF cur_user IS NOT NULL
        AND EXISTS(SELECT *
                   FROM Playlists
                   WHERE Playlists.playlist_id = playlist_id_arg
                     AND Playlists.owner_id = cur_user.user_id) THEN
        LOOP
            last_position := (SELECT coalesce(max(SongInPlaylists.position), 0)
                              FROM SongInPlaylists
                              WHERE SongInPlaylists.playlist_id = playlist_id_arg);

            IF last_position = prev_last_position THEN
                RETURN FALSE;
            END IF;
            prev_last_position := last_position;

            INSERT INTO SongInPlaylists (playlist_id, song_id, position)
            VALUES (playlist_id_arg, song_id_arg, last_position + 1)
            ON CONFLICT (playlist_id, position) DO NOTHING;

            GET DIAGNOSTICS inserted_songs = ROW_COUNT;

            IF inserted_songs = 1 THEN
                RETURN TRUE;
            END IF;
        END LOOP;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Serializable
CREATE OR REPLACE FUNCTION delete_song_from_playlist(login_arg VARCHAR(100),
                                                     pass_arg TEXT,
                                                     playlist_id_arg INT,
                                                     position_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user               Users := check_credentials(login_arg, pass_arg);
    max_number_in_playlist INT;
BEGIN
    IF cur_user IS NOT NULL
        AND EXISTS(SELECT *
                   FROM Playlists
                   WHERE Playlists.playlist_id = playlist_id_arg
                     AND Playlists.owner_id = cur_user.user_id) THEN
        BEGIN
            DELETE
            FROM SongInPlaylists
            WHERE SongInPlaylists.playlist_id = playlist_id_arg
              AND SongInPlaylists.position = position_arg;

            max_number_in_playlist := (SELECT max(SongInPlaylists.position)
                                       FROM SongInPlaylists
                                       WHERE SongInPlaylists.playlist_id = playlist_id_arg);

            IF max_number_in_playlist IS NOT NULL THEN
                FOR i IN (position_arg + 1)..max_number_in_playlist
                    LOOP
                        UPDATE SongInPlaylists
                        SET position = position - 1
                        WHERE SongInPlaylists.playlist_id = playlist_id_arg
                          AND SongInPlaylists.position = i;
                    END LOOP;
            END IF;

            RETURN TRUE;
        END;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION rate_album(login_arg VARCHAR(100),
                                      pass_arg TEXT,
                                      album_id_arg INT,
                                      rating_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user Users := check_credentials(login_arg, pass_arg);
BEGIN
    IF cur_user IS NOT NULL AND rating_arg BETWEEN 1 AND 5 THEN
        BEGIN
            INSERT INTO AlbumRatings (album_id, user_id, rating)
            VALUES (album_id_arg, cur_user.user_id, rating_arg)
            ON CONFLICT (album_id, user_id) DO UPDATE SET rating = rating_arg;

            RETURN TRUE;
        END;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION rate_song(login_arg VARCHAR(100),
                                     pass_arg TEXT,
                                     album_id_arg INT,
                                     rating_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user Users := check_credentials(login_arg, pass_arg);
BEGIN
    IF cur_user IS NOT NULL AND rating_arg BETWEEN 1 AND 5 THEN
        BEGIN
            INSERT INTO SongRatings (song_id, user_id, rating)
            VALUES (album_id_arg, cur_user.user_id, rating_arg)
            ON CONFLICT (song_id, user_id) DO UPDATE SET rating = rating_arg;

            RETURN TRUE;
        END;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION add_artist_photo(artist_id_arg INT,
                                            photo_path_arg VARCHAR(200)) RETURNS BOOLEAN AS
$$
DECLARE
    new_photos_count    INT;
    max_sequence_number INT;
    prev_max_number     INT := -1;
BEGIN
    IF EXISTS(SELECT *
              FROM Artists
              WHERE Artists.artist_id = artist_id_arg) THEN
        LOOP
            max_sequence_number := (SELECT coalesce(max(ArtistPhotos.sequence_number), 0)
                                    FROM ArtistPhotos
                                    WHERE ArtistPhotos.artist_id = artist_id_arg);
            IF max_sequence_number = prev_max_number THEN
                RETURN FALSE;
            END IF;
            prev_max_number := max_sequence_number;

            INSERT INTO ArtistPhotos (artist_id, photo_path, sequence_number)
            VALUES (artist_id_arg, photo_path_arg, max_sequence_number + 1)
            ON CONFLICT (artist_id, sequence_number) DO NOTHING;

            GET DIAGNOSTICS new_photos_count = ROW_COUNT;

            IF new_photos_count = 1 THEN
                RETURN TRUE;
            END IF;
        END LOOP;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE FUNCTION add_album_cover(album_id_arg INT,
                                           cover_path_arg VARCHAR(200)) RETURNS BOOLEAN AS
$$
DECLARE
    new_covers_count    INT;
    max_sequence_number INT;
    prev_max_number     INT := -1;
BEGIN
    IF EXISTS(SELECT *
              FROM Albums
              WHERE Albums.album_id = album_id_arg) THEN
        LOOP
            max_sequence_number := (SELECT coalesce(max(AlbumCovers.sequence_number), 0)
                                    FROM AlbumCovers
                                    WHERE AlbumCovers.album_id = album_id_arg);
            IF max_sequence_number = prev_max_number THEN
                RETURN FALSE;
            END IF;
            prev_max_number := max_sequence_number;

            INSERT INTO AlbumCovers (album_id, cover_path, sequence_number)
            VALUES (album_id_arg, cover_path_arg, max_sequence_number + 1)
            ON CONFLICT (album_id, sequence_number) DO NOTHING;

            GET DIAGNOSTICS new_covers_count = ROW_COUNT;

            IF new_covers_count = 1 THEN
                RETURN TRUE;
            END IF;
        END LOOP;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE PROCEDURE create_album_with_new_song(album_id_arg INT,
                                                       album_name_arg VARCHAR(200),
                                                       album_release_date_arg DATE,
                                                       album_author_ids INT[],
                                                       song_id_arg INT,
                                                       song_name_arg VARCHAR(200),
                                                       song_text_arg TEXT,
                                                       song_duration_arg INTERVAL,
                                                       song_author_ids INT[]) AS
$$
BEGIN
    CALL create_new_album(album_id_arg, album_name_arg,
                          album_release_date_arg, album_author_ids, song_id_arg);
    CALL create_new_song(album_id_arg, song_id_arg, song_name_arg,
                         song_text_arg, song_duration_arg, song_author_ids);

    INSERT INTO SongInAlbums (song_id, album_id, position)
    VALUES (song_id_arg, album_id_arg, 1);
    RETURN;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE PROCEDURE create_album_with_existing_song(album_id_arg INT,
                                                            album_name_arg VARCHAR(200),
                                                            album_release_date_arg DATE,
                                                            album_author_ids INT[],
                                                            song_id_arg INT) AS
$$
BEGIN
    CALL create_new_album(album_id_arg, album_name_arg,
                          album_release_date_arg, album_author_ids, song_id_arg);
    INSERT INTO SongInAlbums (song_id, album_id, position)
    VALUES (song_id_arg, album_id_arg, 1);
    RETURN;
END;
$$
    LANGUAGE plpgsql;

-- Read commited
CREATE OR REPLACE PROCEDURE add_existing_song_to_album(album_id_arg INT,
                                                       song_id_arg INT) AS
$$
DECLARE
    last_position       INT;
    prev_position       INT := -1;
    inserted_rows_count INT;
BEGIN
    LOOP
        last_position := (SELECT max(SongInAlbums.position)
                          FROM SongInAlbums
                          WHERE SongInAlbums.album_id = album_id_arg);

        IF last_position = prev_position THEN
            ROLLBACK;
        END IF;
        prev_position := last_position;

        INSERT INTO SongInAlbums (song_id, album_id, position)
        VALUES (song_id_arg, album_id_arg, last_position + 1)
        ON CONFLICT (album_id, position) DO NOTHING;

        GET DIAGNOSTICS inserted_rows_count = ROW_COUNT;

        IF inserted_rows_count = 1 THEN
            RETURN;
        END IF;
    END LOOP;
END;
$$
    LANGUAGE plpgsql;

-- Read copmmited
CREATE OR REPLACE PROCEDURE add_new_song_to_album(album_id_arg INT,
                                                  song_id_arg INT,
                                                  song_name_arg VARCHAR(200),
                                                  song_text_arg TEXT,
                                                  song_duration_arg INTERVAL,
                                                  song_author_ids INT[]) AS
$$
BEGIN
    CALL create_new_song(album_id_arg, song_id_arg, song_name_arg,
                         song_text_arg, song_duration_arg, song_author_ids);

    CALL add_existing_song_to_album(album_id_arg, song_id_arg);
    RETURN;
END;
$$
    LANGUAGE plpgsql;

-- Serializable
CREATE OR REPLACE FUNCTION move_song_in_playlist(login_arg VARCHAR(100),
                                                 pass_arg TEXT,
                                                 playlist_id_arg INT,
                                                 from_position_arg INT,
                                                 to_position_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    cur_user Users := check_credentials(login_arg, pass_arg);
BEGIN

    IF cur_user IS NULL OR NOT EXISTS(
            SELECT *
            FROM Playlists
            WHERE Playlists.playlist_id = playlist_id_arg
              AND Playlists.owner_id = cur_user.user_id
        ) OR (SELECT count(*)
              FROM SongInPlaylists
              WHERE SongInPlaylists.playlist_id = playlist_id_arg
                AND (SongInPlaylists.position = from_position_arg
                  OR SongInPlaylists.position = to_position_arg)) < 2 THEN
        RETURN FALSE;
    END IF;

    UPDATE SongInPlaylists
    SET position = -1
    WHERE playlist_id = playlist_id_arg
      AND position = from_position_arg;

    IF from_position_arg < to_position_arg THEN
        FOR i IN from_position_arg + 1 .. to_position_arg
            LOOP
                UPDATE SongInPlaylists
                SET position = position - 1
                WHERE SongInPlaylists.playlist_id = playlist_id_arg
                  AND position = i;
            END LOOP;
    ELSE
        FOR i IN REVERSE from_position_arg - 1..to_position_arg
            LOOP
                UPDATE SongInPlaylists
                SET position = position + 1
                WHERE SongInPlaylists.playlist_id = playlist_id_arg
                  AND position = i;
            END LOOP;
    END IF;

    UPDATE SongInPlaylists
    SET position = to_position_arg
    WHERE SongInPlaylists.playlist_id = playlist_id_arg
      AND position = -1;

    RETURN TRUE;
END;
$$
    LANGUAGE plpgsql;

-- Serializable
CREATE OR REPLACE FUNCTION delete_song_from_album(album_id_arg INT,
                                                  position_arg INT) RETURNS BOOLEAN AS
$$
DECLARE
    max_number_in_album   INT;
    deleted_song_id       INT;
    album_main_song_id    INT;
    another_song_id       INT;
    album_by_song         INT;
    another_album_by_song INT;
BEGIN
    deleted_song_id := (SELECT SongInAlbums.song_id
                        FROM SongInAlbums
                        WHERE SongInAlbums.album_id = album_id_arg
                          AND SongInAlbums.position = position_arg);

    IF deleted_song_id IS NULL THEN
        RETURN FALSE;
    END IF;

    DELETE
    FROM SongInAlbums
    WHERE SongInAlbums.album_id = album_id_arg
      AND SongInAlbums.song_id = deleted_song_id;

    max_number_in_album := (SELECT max(SongInAlbums.position)
                            FROM SongInAlbums
                            WHERE SongInAlbums.album_id = album_id_arg);

    IF max_number_in_album IS NOT NULL THEN
        FOR i IN (position_arg + 1)..max_number_in_album
            LOOP
                UPDATE SongInAlbums
                SET position = position - 1
                WHERE SongInAlbums.album_id = album_id_arg
                  AND SongInAlbums.position = i;
            END LOOP;
    END IF;

    album_main_song_id := (SELECT Albums.song_id
                           FROM Albums
                           WHERE Albums.album_id = album_id_arg);

    IF album_main_song_id = deleted_song_id THEN
        BEGIN
            another_song_id := (SELECT SongInAlbums.song_id
                                FROM SongInAlbums
                                WHERE SongInAlbums.album_id = album_id_arg
                                  AND SongInAlbums.song_id <> deleted_song_id);

            IF another_song_id IS NULL THEN
                BEGIN
                    DELETE
                    FROM AlbumAuthors
                    WHERE album_id = album_id_arg;

                    DELETE
                    FROM Albums
                    WHERE Albums.album_id = album_id_arg;
                END;
            ELSE
                UPDATE Albums
                SET song_id = another_song_id
                WHERE album_id = album_id_arg;
            END IF;
        END;
    END IF;

    album_by_song := (SELECT Songs.album_id
                      FROM Songs
                      WHERE Songs.song_id = deleted_song_id);

    IF album_by_song = album_id_arg THEN
        BEGIN
            another_album_by_song := (SELECT SongInAlbums.album_id
                                      FROM SongInAlbums
                                      WHERE SongInAlbums.song_id = deleted_song_id
                                        AND SongInAlbums.album_id <> album_id_arg);

            IF another_album_by_song IS NULL THEN
                BEGIN
                    DELETE
                    FROM SongAuthors
                    WHERE song_id = deleted_song_id;

                    DELETE
                    FROM Songs
                    WHERE Songs.song_id = deleted_song_id;
                END;
            ELSE
                UPDATE Songs
                SET album_id = another_album_by_song
                WHERE song_id = deleted_song_id;
            END IF;
        END;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
