INSERT INTO Artists (artist_id, name)
VALUES (1, 'Death In June');

INSERT INTO Artists (artist_id, name)
VALUES (2, 'David Tibet');

CALL create_album_with_new_song(1, 'Free Tibet', DATE 'September 3, 2006', ARRAY [1, 2],
                                1, 'Death Books I', NULL, INTERVAL '5 mins, 55 secs', ARRAY [1, 2]);
CALL add_new_song_to_album(1, 2, 'This Is Paradise I', NULL, INTERVAL '4 mins, 41 secs', ARRAY [1]);
CALL add_new_song_to_album(1, 3, 'Love Books', NULL, INTERVAL '4 mins, 12 secs', ARRAY [1, 2]);


INSERT INTO Artists (artist_id, name)
VALUES (3, 'Boyd Rice');

CALL create_album_with_new_song(2, 'Heaven Sent', NULL, ARRAY [1],
                                4, 'Love Love Love', NULL, INTERVAL '3 mins, 53 secs', ARRAY [1, 3]);
CALL add_new_song_to_album(2, 5, 'Preserve Thy Loneliness', NULL, INTERVAL '4 mins, 21 secs', ARRAY [1, 3]);

CALL create_album_with_new_song(3, 'All Pigs Must Die', NULL, ARRAY [1],
                                6, 'All Pigs Must Die', NULL, INTERVAL '3 mins, 00 secs', ARRAY [1]);
CALL add_new_song_to_album(3, 7, 'Tick Tock', NULL, INTERVAL '3 mins, 06 secs', ARRAY [1]);

CALL create_album_with_existing_song(4, 'Anthology', NULL, ARRAY [1], 3);
CALL add_existing_song_to_album(4, 6);

INSERT INTO Artists (artist_id, name)
VALUES (4, 'Current 93'),
       (5, 'Akiko Hada'),
       (6, 'Bj√∂rk'),
       (7, 'John Balance');

CALL create_album_with_new_song(
        5, 'Calling For Vanished Faces', NULL, ARRAY [4],
        8, 'Oh Coal Black Smith',
        'Oh she looked out of the window
        As white as any milk
        But he looked into the window
        As black as any silk
        Hello, hello, hello, hello
        Hello you coal black smith
        Oh what is your silly song?
        You shall never change my maiden name
        That I have kept so long
        I''d rather die a maid yes
        But then she said
        And be buried in my grave yes
        And then she said
        That I''d have such a nasty
        Husky dusky musty funky
        Coal black smith
        A maiden will I die
        Then she became a duck
        A duck all on the stream
        And he became a water dog
        And fetched her back again
        Then she became a hare
        A hare all on the plain
        And he became a greyhound dog
        And fetched her back again
        Then she became a fly
        A fly all in the air
        And he became a spider
        And fetched her to his lair

        Man is a beast of prey
        The beast of prey conquers contries
        Founds great realms by subdigation of other subdigators
        Forms states and organises civilisations
        in order to enjoy his brooding in peace& Attack and defence
        Suffering and struggle
        Victory and defeat
        Domination and servitude
        All sealed with blood
        This is the entire history of human race

        And she became a corpse
        A corpse all in the ground
        And he became the cold grey clay
        And smothered her all around',
        INTERVAL '4 mins, 44 secs', ARRAY [4]
    );

CALL add_new_song_to_album(5, 9, 'Falling', NULL, INTERVAL '4 mins, 22 secs', ARRAY [4, 5, 6]);
CALL add_new_song_to_album(5, 10, 'Lucifer Over London', NULL, INTERVAL '7 mins, 44 secs', ARRAY [4, 7]);

SELECT add_artist_photo(1, 'artists/death_in_june/1.png');

SELECT add_artist_photo(1, 'artists/death_in_june/2.png');

SELECT create_user(1, 'user1', 'password_1');
SELECT create_user(2, 'user2', 'password_2');
SELECT create_user(3, 'user3', 'password_3');
SELECT create_user(4, 'user4', 'password_4');
SELECT create_user(5, 'user5', 'password_5');

SELECT add_user_playlist('user1', 'password_1', 1, 'user_1_playlist_1');
SELECT add_user_playlist('user1', 'password_1', 2, 'user_1_playlist_2');

SELECT add_song_to_playlist('user1', 'password_1', 1, 1);
SELECT add_song_to_playlist('user1', 'password_1', 1, 1);
SELECT add_song_to_playlist('user1', 'password_1', 1, 1);
SELECT add_song_to_playlist('user1', 'password_1', 1, 2);

SELECT add_song_to_playlist('user1', 'password_1', 2, 1);
SELECT add_song_to_playlist('user1', 'password_1', 2, 2);
SELECT add_song_to_playlist('user1', 'password_1', 2, 3);

SELECT rate_album('user1', 'password_1', 1, 5);
SELECT rate_album('user2', 'password_2', 1, 4);

SELECT rate_song('user1', 'password_1', 1, 5);
SELECT rate_song('user2', 'password_2', 1, 5);
SELECT rate_song('user3', 'password_3', 1, 5);
SELECT rate_song('user4', 'password_4', 1, 5);

SELECT rate_song('user1', 'password_1', 2, 3);

SELECT rate_album('user1', 'password_1', 2, 5);
SELECT rate_album('user2', 'password_2', 2, 3);

SELECT rate_song('user1', 'password_1', 6, 5);
SELECT rate_song('user2', 'password_2', 6, 5);
SELECT rate_song('user3', 'password_3', 6, 5);
SELECT rate_song('user4', 'password_4', 6, 5);

SELECT rate_song('user1', 'password_1', 7, 2);

SELECT add_user_playlist('user1', 'password_1', 3, 'user_1_playlist_3');
SELECT add_song_to_playlist('user1', 'password_1', 3, 1);
SELECT add_song_to_playlist('user1', 'password_1', 3, 2);
SELECT add_song_to_playlist('user1', 'password_1', 3, 3);
SELECT add_song_to_playlist('user1', 'password_1', 3, 4);
SELECT add_song_to_playlist('user1', 'password_1', 3, 5);

SELECT move_song_in_playlist('user1', 'password_1', 3, 2, 4);
SELECT move_song_in_playlist('user1', 'password_1', 3, 4, 2);

SELECT delete_song_from_playlist('user1', 'password_1', 3, 3);
SELECT delete_song_from_playlist('user1', 'password_1', 3, 3);
SELECT delete_song_from_playlist('user1', 'password_1', 3, 3);
SELECT delete_song_from_playlist('user1', 'password_1', 3, 1);
SELECT delete_song_from_playlist('user1', 'password_1', 3, 1);

SELECT add_user_playlist('user2', 'password_2', 4, 'user_2_playlist_1');

CALL create_album_with_new_song(6, 'Some album', DATE 'September 3, 2006', ARRAY [1],
                                11, 'Some song', NULL, INTERVAL '5 mins, 55 secs', ARRAY [1]);
CALL add_new_song_to_album(6, 12, 'Another song', NULL, INTERVAL '4 mins, 41 secs', ARRAY [1]);
SELECT delete_song_from_album(6, 1);
SELECT delete_song_from_album(6, 1);




