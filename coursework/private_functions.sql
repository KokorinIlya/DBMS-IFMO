CREATE OR REPLACE FUNCTION check_credentials(login_arg VARCHAR(100),
                                             pass_arg TEXT) RETURNS Users AS
$$
DECLARE
    cur_user Users;
BEGIN
    SELECT Users.*
    INTO cur_user
    FROM Users
    WHERE Users.login = login_arg
      AND crypt(pass_arg, pass_hash_with_salt) = pass_hash_with_salt;

    RETURN cur_user;
END;
$$
    LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE create_new_album(album_id_arg INT,
                                             album_name_arg VARCHAR(200),
                                             album_release_date_arg DATE,
                                             album_author_ids INT[],
                                             song_id_arg INT) AS
$$
BEGIN
    IF array_length(album_author_ids, 1) = 0 THEN
        ROLLBACK;
    END IF;

    INSERT INTO Albums (album_id, name, artist_id, song_id, release_date)
    VALUES (album_id_arg, album_name_arg, album_author_ids[1], song_id_arg, album_release_date_arg);

    FOR i IN 1..array_length(album_author_ids, 1)
        LOOP
            INSERT INTO AlbumAuthors (album_id, artist_id)
            VALUES (album_id_arg, album_author_ids[i]);
        END LOOP;

    RETURN;
END;
$$
    LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE create_new_song(album_id_arg INT,
                                            song_id_arg INT,
                                            song_name_arg VARCHAR(200),
                                            song_text_arg TEXT,
                                            song_duration_arg INTERVAL,
                                            song_author_ids INT[]) AS
$$
BEGIN
    IF array_length(song_author_ids, 1) = 0 THEN
        ROLLBACK;
    END IF;
    INSERT INTO Songs (song_id, name, text, duration, album_id, artist_id)
    VALUES (song_id_arg, song_name_arg, song_text_arg, song_duration_arg, album_id_arg, song_author_ids[1]);

    FOR i IN 1..array_length(song_author_ids, 1)
        LOOP
            INSERT INTO SongAuthors (song_id, artist_id)
            VALUES (song_id_arg, song_author_ids[i]);
        END LOOP;

    RETURN;
END;
$$
    LANGUAGE plpgsql;