#' Download archives of GitHub repositories within an organization
#'
#' @param organizations Organization name(s) (vector)
#' @param extra_repos Named vector of extra repository names where names are organization names.
#' @param dest_folder Where to save the folders with the archives.
#'
#' @details
#'
#' You will need a [GitHub Personal Access Token](https://usethis.r-lib.org/articles/git-credentials.html).
#'
#' The reason why you might need `extra_repos` is if you want to download archives
#' of private repositories, while using a GitHub Personal Access Token with no scope.
#'
#' [GitHub documentation on archives](https://docs.github.com/en/repositories/archiving-a-github-repository/backing-up-a-repository).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' download_organization_repos(c("maelle-test", "maelle-test"))
#' }
download_organization_repos <- function(organizations = NULL,
  extra_repos = NULL,
  dest_folder = getwd()) {

  if (!dir.exists(dest_folder)) dir.create(dest_folder)
  withr::local_dir(dest_folder)

  repos <- purrr::map(organizations, launch_org_migrations, extra_repos = extra_repos) |>
    unlist(recursive = FALSE)

  repo_names <- purrr::map_chr(repos, function(x) x$name)

  message("Waiting one minute for things to kick off properly before downloads...")
  Sys.sleep(60)

  start_time <- Sys.time()

  time_spent <- function(start_time) {
    ts <- difftime(Sys.time(), start_time, units = "mins")
    message(sprintf("Spent %s minutes", ts))
    ts
  }

  message(sprintf("%s archives to be saved.", length(repos)))

  while (length(repos) > 0 && time_spent(start_time = start_time) < 120) {
    status <- purrr::map_chr(repos, function(repo) repo$migration_state)
    ready_repos <- repos[status == "exported"]
    purrr::walk(ready_repos, function(repo) repo$launch_download())
    repos <- repos[status != "exported"]
    if (length(repos) > 0) message(sprintf("Still not saved: %s", purrr::map_chr(repos, function(x) x$name)))
  }

  leftover <- purrr::map_chr(repos, function(x) x$name)
  if (length(leftover) > 0) message(sprintf("Left-over: %s", leftover))

  tibble::tibble(
    repos = repo_names,
    exported = !(repo_names %in% leftover)
  )
}

launch_org_migrations <- function(organization, extra_repos) {
    repo_names <- gh::gh(
    "/orgs/{org}/repos",
    org = organization,
    type = "all",
    per_page = 100,
    .limit = Inf
  ) |>
    purrr::map_chr("name")

  repo_names <- c(
    repo_names,
    extra_repos[names(extra_repos) == organization]
  ) |>
    unique()

  message(sprintf("Launching archive creation for organization %s", organization))
  purrr::map(repo_names, repo$new, organization = organization)

}
