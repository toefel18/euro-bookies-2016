CREATE TABLE bets
(
  id INT NOT NULL AUTO_INCREMENT,
  team CHAR(2) NOT NULL,
  amount INT NOT NULL,
  PRIMARY KEY(id),
  FOREIGN KEY (team) REFERENCES teams (countryCode) ON DELETE CASCADE
);
