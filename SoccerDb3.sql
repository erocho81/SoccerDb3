--Soccer DB3
-- These are the last exercises for the SoccerDB3.
-- These are the solutions I provided for the PosgreSQL activites required to pass the course I completed.

-- For this first exercise we are required to obtain the countries where more matches have taken place in. We are looking for the name of the country.
--We want to show the name of the country, total matches, and the stadium name.

-- We were required to create CTE's for these exercises:


WITH countryrank AS			  
	(SELECT
	 	c.country_name,
		s.stadium_name,
 		COUNT (m.*) AS numero_partidos,
		RANK () OVER (ORDER BY COUNT (m.*)DESC) AS rango
 
    FROM euro2021.tb_match AS m

	INNER JOIN euro2021.tb_stadium s
		ON m.stadium_code = s.stadium_code

	INNER JOIN euro2021.tb_country c
		ON s.country_code = c.country_code
 
	GROUP BY c.country_name, 
		 	 s.stadium_name
	)


SELECT
	countryrank.country_name,
	countryrank.stadium_name,
	countryrank.numero_partidos

FROM countryrank

WHERE rango = 1
;


-- Now we want to obtain a list of all teams to check on how many matches they won as visitors, locals or if there was a drawn.
--We want to relate the nationality of the teams to the country of the stadiums to know if these teams were more lucky when playing in their own countries.

WITH home AS

	(SELECT 
		c.country_name,
		SUM (CASE WHEN m.home_goals>m.visitor_goals THEN 1 ELSE 0 END) wins_home,
		SUM (CASE WHEN m.home_goals=m.visitor_goals THEN 1 else 0 END) draw_home
		
	FROM euro2021.tb_match m

	JOIN euro2021.tb_team t
		ON m.home_team_code = t.team_code
		
	JOIN euro2021.tb_country c
 		ON t.country_code = c.country_code

	GROUP BY c.country_name
	),


visitor AS

	(SELECT 
		c.country_name,
		SUM (CASE WHEN m.home_goals<m.visitor_goals THEN 1 ELSE 0 END) wins_visitor,
		SUM (CASE WHEN m.home_goals=m.visitor_goals THEN 1 ELSE 0 END) draw_visitor
	
	FROM euro2021.tb_match m

	JOIN euro2021.tb_team t
		ON m.visitor_team_code = t.team_code
		
	JOIN euro2021.tb_country c
 		ON t.country_code = c.country_code

		GROUP BY c.country_name
	 )


SELECT 
	COALESCE (home.country_name, visitor.country_name) AS country_name,
	COALESCE (home.wins_home,0) AS wins_home,
	COALESCE (visitor.wins_visitor,0) AS wins_visitor,
	COALESCE (SUM (home.draw_home+visitor.draw_visitor),0) AS draw

FROM home

RIGHT JOIN visitor ON
	home.country_name = visitor.country_name

GROUP BY 
	home.country_name,
	visitor.country_name, 
	home.wins_home,
	visitor.wins_visitor

ORDER BY 
	wins_visitor DESC, 
	wins_home DESC, 
	country_name

;

--For this next exercise we want to show with aggregated functions, information about the stadium and the final phase of the championship.
--The fields that we are going to show are:
--*The name of the stadium.
--*The phase name.
--*The total goals for each phase (locals+visitors)
--*The difference between the goals of that stadium in that phase and the average of goals of that phase on all stadiums.
--*The difference between the total goals in that stadium and phase and the maximum nbr of goals in that stadium all along the championship.



	(SELECT 
		s.stadium_name,
		p.phase_name,
		m.phase_code,
		SUM (m.home_goals+m.visitor_goals) AS goals_phase_by_stadium

	FROM euro2021.tb_match m

	JOIN euro2021.tb_stadium s
		ON s.stadium_code = m.stadium_code

	JOIN euro2021.tb_phase p
		ON p.phase_code= m.phase_code

	GROUP BY s.stadium_name, 
	 	     p.phase_name,
	 	     m.phase_code)


SELECT 
	mainquery.stadium_name,
	mainquery.phase_name,
	mainquery.goals_phase_by_stadium,
	goals_phase_by_stadium - ROUND(AVG (mainquery.goals_phase_by_stadium) 
								   OVER (PARTITION BY  mainquery.phase_name),2) AS dif_avg,
	goals_phase_by_stadium - (MAX (mainquery.goals_phase_by_stadium) 
							  OVER (PARTITION BY mainquery.stadium_name)) AS dif_max

FROM mainquery

ORDER BY mainquery.stadium_name,
		 mainquery.phase_code
;


-- We want to check a list of the referees to know if they were specially soft or hard to any team in particular.
-- For that we are goind to list:
--*Name of the referee
--*Country of the team
--*Country of the referee
--*Total nbr of cards shown for that referee to that team.
--*Avg of cards shown for that referee to all teams he has judged to. The avg is per team not per match.
--* Max nbr of cards shown by the referee to any of the teams he has judged to.



WITH cte_cards_home AS 

	(SELECT 
		m.home_team_code AS team_code,
		m.referee_code AS referee_code,
		COALESCE (SUM (m.home_yellow_cards+m.home_red_cards),0) AS cards

	FROM euro2021.tb_match m

	GROUP BY m.home_team_code,m.referee_code
	 ),


cte_cards_visitor AS 
 
	(SELECT 
		m.visitor_team_code AS team_code,
		m.referee_code  AS referee_code,
		(COALESCE (SUM (visitor_yellow_cards+visitor_red_cards),0)) AS cards

	FROM euro2021.tb_match m

	GROUP BY m.visitor_team_code,m.referee_code
	ORDER BY team_code, referee_code
	),


cte_cards_by_team_final AS
	(SELECT 
		team_code,
		referee_code,
		cards
	FROM cte_cards_home
	
	UNION ALL
	
	SELECT 
		team_code,
		referee_code,
		cards
	FROM cte_cards_visitor),


cte_cards_team_by_referee AS
	(SELECT 
		team_code,
		referee_code,
		SUM (cards) total_cards


 	FROM cte_cards_by_team_final
 
	GROUP BY team_code,referee_code

	)


SELECT 
	r.referee_name AS arbitro,
	c1.country_name AS pais_equipo,
	c2.country_name AS pais_arbitro,
	total_cards,
	ROUND (AVG (total_cards) 
		    OVER (PARTITION BY cte_cards_team_by_referee.referee_code),2),
	MAX (total_cards) 
			OVER (PARTITION BY cte_cards_team_by_referee.referee_code)

FROM cte_cards_team_by_referee


JOIN euro2021.tb_team t
	ON cte_cards_team_by_referee.team_code = t.team_code

JOIN euro2021.tb_referee r
	ON cte_cards_team_by_referee.referee_code = r.referee_code

JOIN euro2021.tb_country c1
	ON t.country_code = c1.country_code

JOIN euro2021.tb_country c2
	ON r.country = c2.country_code

ORDER BY arbitro, total_cards DESC
;


-- In the next exercise we are going to use a recursive CTE to show the relationship between referees shown in the column referee_manager_code from the table tb_referee.
-- We will show which referees depend hierarchically to any other and show this hierarchy.
-- We don't know on beforehand of many levels of hierarchy are there for the referees.

WITH RECURSIVE arbitros AS
	(SELECT 
		r.referee_code,
		r.referee_name,
		r.referee_manager_code,
		CAST (r.referee_name AS TEXT) AS jerarquia
	
	FROM euro2021.tb_referee r
	
	WHERE r.referee_name = 'Marco Di Bello'
	
	UNION ALL
	
	SELECT 
		r2.referee_code,
		r2.referee_name,
		r2.referee_manager_code,
		CAST (r2.referee_name  || '-->' || a.jerarquia AS Text) AS jerarquia

	FROM euro2021.tb_referee r2

	INNER JOIN arbitros a
		ON (r2.referee_manager_code = a.referee_code)
	)


SELECT 
	referee_code,
	referee_name,
	jerarquia

FROM arbitros

ORDER BY referee_code;


-- The next exercise is going to show code on how to calculate the statistic data for the schema euro2021


EXPLAIN ANALYZE 
	SELECT * 
	FROM euro2021.tb_country;
 
EXPLAIN ANALYZE 
	SELECT * 
	FROM euro2021.tb_match;

EXPLAIN ANALYZE 
	SELECT * 
	FROM euro2021.tb_phase;

EXPLAIN ANALYZE
	SELECT * 
	FROM euro2021.tb_referee;

EXPLAIN ANALYZE 
	SELECT * 
	FROM euro2021.tb_stadium;

EXPLAIN ANALYZE 
	SELECT * 
	FROM euro2021.tb_team;
	
	
-- Now we are going to create different indexes 

CREATE INDEX idx_city
	ON euro2021.tb_stadium 
	USING btree (country_code,city_code);

CREATE INDEX idx_stadium_name
	ON euro2021.tb_stadium 
	USING btree (stadium_name);


CREATE INDEX idx_city_code
	ON euro2021.tb_city
	USING btree (country_code,city_code);


-- Finally we want to show the execution plan for the query:


EXPLAIN 

SELECT   
	S.stadium_code, 
	S.stadium_name, 
	C.city_name
	
FROM     euro2021.tb_stadium S,
         euro2021.tb_city C
		 
WHERE    S.country_code = C.country_code 
		AND S.city_code = C.city_code 
		
ORDER BY S.stadium_name ASC;

