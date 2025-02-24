CREATE SCHEMA track;
DROP TABLE IF EXISTS track.feedbacks;
DROP TABLE IF EXISTS track.dialogues;

CREATE TABLE track.dialogues(
  id VARCHAR(155),
  user_id CHAR(20),
  created_at VARCHAR(30),
  question TEXT,
  answer TEXT
);

CREATE TABLE track.feedbacks(
  user_id CHAR(20),
  dialogue_id VARCHAR(155),
  created_at VARCHAR(30),
  feedback INT

);
