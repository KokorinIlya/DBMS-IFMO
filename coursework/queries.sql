CREATE OR REPLACE VIEW Feats AS
(
SELECT SongAuthors.song_id,
       SongInAlbums.album_id,
       SongAuthors.artist_id
FROM SongAuthors
         INNER JOIN SongInAlbums ON SongAuthors.song_id = SongInAlbums.song_id
    EXCEPT
SELECT SongInAlbums.song_id,
       AlbumAuthors.album_id,
       AlbumAuthors.artist_id
FROM AlbumAuthors
         INNER JOIN SongInAlbums ON AlbumAuthors.album_id = SongInAlbums.album_id

    );

SELECT Songs.name   AS song_name,
       Albums.name  AS album_name,
       Artists.name AS artist_name
FROM Feats
         NATURAL JOIN Artists
         INNER JOIN Songs ON Feats.song_id = Songs.song_id
         INNER JOIN Albums ON Feats.album_id = Albums.album_id;

CREATE OR REPLACE FUNCTION random_shuffle_playlist(login_arg VARCHAR(100), pass_arg TEXT, playlist_id_arg INT)
    RETURNS TABLE
            (
                song_id INT
            )
AS
$$
DECLARE
    cur_user Users := check_credentials(login_arg, pass_arg);
BEGIN
    IF cur_user IS NOT NULL
        AND EXISTS(SELECT *
                   FROM Playlists
                   WHERE Playlists.playlist_id = playlist_id_arg
                     AND Playlists.owner_id = cur_user.user_id) THEN
        RETURN QUERY SELECT SongsWithPriorities.song_id
                     FROM (SELECT SongInPlaylists.song_id,
                                  (random() * 10000000) :: INT AS priority
                           FROM SongInPlaylists
                           WHERE SongInPlaylists.playlist_id = playlist_id_arg
                           ORDER BY priority) AS SongsWithPriorities;
    ELSE
        BEGIN
            RAISE NOTICE 'User is not authorized, playlist doesn''t exists or use cannot access playlist';
            ROLLBACK;
        END;
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT random_shuffle_playlist('user1', 'password_1', 1);

CREATE OR REPLACE VIEW AlbumDurations AS
(
SELECT SongInAlbums.album_id,
       sum(Songs.duration) AS summary_duration
FROM SongInAlbums
         INNER JOIN Songs ON SongInAlbums.song_id = Songs.song_id
GROUP BY SongInAlbums.album_id
    );

SELECT Albums.name,
       AlbumDurations.summary_duration
FROM AlbumDurations
         INNER JOIN Albums ON AlbumDurations.album_id = Albums.album_id;

CREATE OR REPLACE VIEW AverageAlbumDurationBySong AS
(
SELECT SongInAlbums.song_id,
       avg(AlbumDurations.summary_duration) AS average_time
FROM SongInAlbums
         INNER JOIN AlbumDurations ON SongInAlbums.album_id = AlbumDurations.album_id
GROUP BY SongInAlbums.song_id
    );

SELECT corr(EXTRACT('epoch' FROM Songs.duration),
            EXTRACT('epoch' FROM AverageAlbumDurationBySong.average_time))
FROM AverageAlbumDurationBySong
         INNER JOIN Songs ON AverageAlbumDurationBySong.song_id = Songs.song_id;

CREATE OR REPLACE VIEW PlaylistsWithRepetitions AS
(
SELECT Result.playlist_id
FROM (
         SELECT CountByPlaylistAndSong.playlist_id,
                max(CountByPlaylistAndSong.repetitions_count) AS max_repetitions_count
         FROM (SELECT SongInPlaylists.playlist_id,
                      SongInPlaylists.song_id,
                      count(*) AS repetitions_count
               FROM SongInPlaylists
               GROUP BY (SongInPlaylists.playlist_id, SongInPlaylists.song_id)) AS CountByPlaylistAndSong
         GROUP BY CountByPlaylistAndSong.playlist_id
     ) AS Result
WHERE Result.max_repetitions_count >= 2
    );

SELECT Playlists.name
FROM PlaylistsWithRepetitions
         INNER JOIN Playlists ON PlaylistsWithRepetitions.playlist_id = Playlists.playlist_id;

CREATE OR REPLACE VIEW AverageAlbumRating AS
(
WITH RatingByAlbumRatings AS (
    SELECT AlbumRatings.album_id,
           avg(AlbumRatings.rating) AS rating_by_album_ratings
    FROM AlbumRatings
    GROUP BY AlbumRatings.album_id
),
     RatingBySongRatings AS (
         SELECT SongInAlbums.album_id,
                avg(AverageSongRating.song_rating) AS rating_by_song_ratings
         FROM (SELECT SongRatings.song_id,
                      avg(SongRatings.rating) AS song_rating
               FROM SongRatings
               GROUP BY SongRatings.song_id) AS AverageSongRating
                  INNER JOIN SongInAlbums USING (song_id)
         GROUP BY SongInAlbums.album_id
     ),
     RatingBySongRatingsWeighted AS (
         SELECT SongInAlbums.album_id,
                avg(SongRatings.rating) AS rating_by_song_ratings_weighted
         FROM SongInAlbums
                  INNER JOIN SongRatings ON SongInAlbums.song_id = SongRatings.song_id
         GROUP BY SongInAlbums.album_id
     )
SELECT album_id,
       RatingByAlbumRatings.rating_by_album_ratings,
       RatingBySongRatings.rating_by_song_ratings,
       RatingBySongRatingsWeighted.rating_by_song_ratings_weighted
FROM RatingByAlbumRatings
         FULL OUTER JOIN RatingBySongRatings USING (album_id)
         FULL OUTER JOIN RatingBySongRatingsWeighted USING (album_id)
    );

SELECT Albums.album_id,
       Albums.name,
       AverageAlbumRating.rating_by_album_ratings,
       AverageAlbumRating.rating_by_song_ratings,
       AverageAlbumRating.rating_by_song_ratings_weighted
FROM AverageAlbumRating
         NATURAL JOIN Albums;

CREATE OR REPLACE VIEW PlaylistsIncludingOtherPlaylists AS
(
SELECT Playlists1.playlist_id AS big_playlist_id,
       Playlists2.playlist_id AS small_playlist_id
FROM Playlists AS Playlists1
         INNER JOIN
     Playlists AS Playlists2 ON Playlists1.owner_id = Playlists2.owner_id
         AND Playlists1.playlist_id <> Playlists2.playlist_id
         AND NOT EXISTS(SELECT DISTINCT SongInPlaylists.song_id
                        FROM SongInPlaylists
                        WHERE SongInPlaylists.playlist_id = Playlists2.playlist_id
                            EXCEPT
                        SELECT DISTINCT SongInPlaylists.song_id
                        FROM SongInPlaylists
                        WHERE SongInPlaylists.playlist_id = Playlists1.playlist_id)
    );

SELECT BigPlaylists.name   AS big_playlist_name,
       SmallPlaylists.name AS small_playlist_name
FROM PlaylistsIncludingOtherPlaylists
         INNER JOIN (SELECT Playlists.playlist_id,
                            Playlists.name
                     FROM Playlists) AS BigPlaylists
                    ON PlaylistsIncludingOtherPlaylists.big_playlist_id = BigPlaylists.playlist_id
         INNER JOIN (SELECT Playlists.playlist_id,
                            Playlists.name
                     FROM Playlists) AS SmallPlaylists
                    ON PlaylistsIncludingOtherPlaylists.small_playlist_id = SmallPlaylists.playlist_id;
