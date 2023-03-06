No reverse dependency failures according to revdepcheck::revdep_check

No breaking changes.

Passes: 
```
devtools::check(remote = TRUE, manual = TRUE)
devtools::check_win_devel()
rhub::check_for_cran()
```
