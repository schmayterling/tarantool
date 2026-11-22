## feature/sql

* Introduced the standard `SUBSTRING(s FROM start [FOR length])` syntax. It
  works the same as `SUBSTR(s, start[, length])`. `SUBSTRING` is now a reserved
  keyword: use double quotes if it is an identifier (gh-13682).
