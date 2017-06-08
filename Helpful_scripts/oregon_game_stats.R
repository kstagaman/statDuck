library(XML)
library(qdap)

append.data <- TRUE
years <- c(2016)

if(append.data == TRUE) {
    load("~/Documents/R_musings/UO_stats/oregon_qb_stats_list", verbose=T)
    qb.stats <- read.table("~/Documents/R_musings/UO_stats/oregon_qb_stats.txt",
                           header=T,
                           sep="\t")
    load("~/Documents/R_musings/UO_stats/oregon_rb_stats_list", verbose=T)
    rb.stats <- read.table("~/Documents/R_musings/UO_stats/oregon_rb_stats.txt",
                           header=T,
                           sep="\t")
    load("~/Documents/R_musings/UO_stats/oregon_game_stats_links", verbose=T)
} else {
    qb.list <- list(NULL)
    qb.stats <- data.frame(NULL)
    rb.list <- list(NULL)
    rb.stats <- data.frame(NULL)
    done.links <- NULL
}

for(year in years) {
    print(year)
    year.link <- paste("http://www.espn.com/college-football/team/schedule/_/id/2483/year",
                       year,
                       sep="/")
    year.html <- htmlParse(year.link)
    all.links <- unlist(xpathApply(year.html, '//a', xmlGetAttr, 'href'))
    game.links <- all.links[grep("recap", all.links)]
    no.http <- game.links[!(grepl("html", game.links))]
    yes.http <- game.links[(grepl("html", game.links))]

    game.links <- sort(c(gsub("//", "http://", no.http), yes.http))
    if(append.data == TRUE) {
        game.links <- game.links[!(game.links %in% done.links)]
    }
    for(game.link in game.links) {
        print(game.link)
        game.html <- htmlParse(game.link)
        boxscore.link <- grep("boxscore",
                              unlist(xpathApply(game.html, '//a', xmlGetAttr, 'href')),
                              value=TRUE)
        n.tbls <- 4
        if(length(boxscore.link) > 0) {
            if(!(grepl("http://www.espn.com", boxscore.link))) {
                boxscore.link <- paste("http://www.espn.com", boxscore.link, sep="")
            }
            n.tbls <- length(readHTMLTable(boxscore.link))
        }

        if(length(boxscore.link)==0 | n.tbls < 4) {
            game.title <- unlist(xpathApply(game.html, '//title', xmlValue))
            game.date <- as.character(as.Date(strsplit(game.title, " - ")[[1]][3],
                                              format='%B %d, %Y'))
            game.month <- strsplit(game.date, "-")[[1]][2]
            game.day <- strsplit(game.date, "-")[[1]][3]
            game.year <- strsplit(game.date, "-")[[1]][1]
            game.day.link <- paste("http://www.sports-reference.com/cfb/boxscores/index.cgi",
                                   "?month=", game.month,
                                   "&day=", game.day,
                                   "&year=", game.year,
                                   sep="")
            game.day.html <- htmlParse(game.day.link)
            boxscore.tbls <- readHTMLTable(game.day.link)
            names(boxscore.tbls) <- c(1:length(boxscore.tbls))
            oregon.index <- unlist(lapply(boxscore.tbls,
                                          function(x) grep("Oregon",
                                                           grep("State",
                                                                x$V1,
                                                                invert=T,
                                                                value=T))))
            opp <- grep("Oregon",
                        boxscore.tbls[[as.numeric(names(oregon.index))]]$V1,
                        invert=T,
                        value=T)
            if(length(opp)==0) {
                opp <- grep("State",
                            boxscore.tbls[[as.numeric(names(oregon.index))]]$V1,
                            value=T)
            }
            boxscore.link <- paste("http://www.sports-reference.com",
                                   grep(paste("boxscores", year, sep="/"),
                                        unlist(xpathApply(game.day.html, '//a',
                                                          xmlGetAttr, 'href')),
                                        value=T)[as.numeric(names(oregon.index))],
                                   sep="")
            print(boxscore.link)
            boxscore.html <- htmlParse(boxscore.link)
            pass.tbl.raw <- readHTMLTable(
                unlist(lapply(xpathApply(boxscore.html, '//comment()', xmlValue),
                              function(x) grep("passing", x, value=T)))
            )
            pass.tbl <- pass.tbl.raw$passing
            pass.tbl[,3:ncol(pass.tbl)] <- apply(pass.tbl[,3:ncol(pass.tbl)], 2, as.numeric)
            pass.tbl <- droplevels(subset(pass.tbl, School=="Oregon"))
            names(pass.tbl)[c(1,3,4,6,9,10)] <- c("QB", "CMP", "ATT", "YDS", "TD", "INT")
            qb.names <- as.character(pass.tbl$QB)

            rush.tbl.raw <- readHTMLTable(
                unlist(lapply(xpathApply(boxscore.html, '//comment()', xmlValue),
                              function(x) grep("rushing", x, value=T)))
            )
            rush.tbl <- rush.tbl.raw$rushing_and_receiving[,1:6]
            rush.tbl[,3:ncol(rush.tbl)] <- apply(rush.tbl[,3:ncol(rush.tbl)], 2, as.numeric)
            rush.tbl <- droplevels(subset(rush.tbl, School=="Oregon" & !(is.na(Att))))
            names(rush.tbl)[c(1, 3, 4, 5)] <- c("Runner", "CAR", "YDS", "AVG")
            runner.names <- as.character(rush.tbl$Runner)
            rb.names <- runner.names[!(runner.names %in% qb.names)]
        } else {
            print(boxscore.link)
            boxscore.tbls <- readHTMLTable(boxscore.link)

            if(grep("ORE", boxscore.tbls$linescore[,1])==1) {
                pass.tbl <- boxscore.tbls[[2]]
                rush.tbl <- boxscore.tbls[[4]]
            } else {
                pass.tbl <- boxscore.tbls[[3]]
                rush.tbl <- boxscore.tbls[[5]]
            }
            opp <- grep("ORE", boxscore.tbls$linescore[,1], invert=T, value=T)
            names(pass.tbl)[1] <- "QB"
            pass.tbl <- droplevels(subset(pass.tbl, !(QB %in% c("TEAM", "Team"))))
            qb.names <- NULL
            for(name in as.character(pass.tbl$QB)) {
                name <- mgsub(c(" II", " Jr."), c("", ""), name)
                chars <- regexpr("[a-z][A-Z][.]", name)
                stop.char <- chars[1]
                new.name <- substr(name, start=1, stop=stop.char)
                qb.names <- c(qb.names, new.name)
            }
            pass.tbl$QB <- qb.names
            temp.df <- with(pass.tbl,
                               data.frame(do.call('rbind',
                                                      strsplit(as.character(`C/ATT`),
                                                               '/',
                                                               fixed=TRUE))))
            names(temp.df) <- c("CMP", "ATT")
            pass.tbl <- cbind(pass.tbl, temp.df)
            pass.tbl[,3:ncol(pass.tbl)] <- apply(pass.tbl[,3:ncol(pass.tbl)], 2, as.numeric)

            names(rush.tbl)[1] <- "Runner"
            rush.tbl <- droplevels(subset(rush.tbl, !(Runner %in% c("TEAM", "Team"))))
            runner.names <- NULL
            for(name in as.character(rush.tbl$Runner)) {
                # name <- as.character(rush.tbl$Runner)[1]
                # print(name)
                name <- mgsub(c(" II", " Jr."), c("", ""), name)
                chars <- regexpr("[a-z][A-Z][.]", name)
                stop.char <- chars[1]
                new.name <- substr(name, start=1, stop=stop.char)
                # print(new.name)
                runner.names <- c(runner.names, new.name)
            }
            rush.tbl$Runner <- runner.names
            rush.tbl[,2:ncol(rush.tbl)] <- apply(rush.tbl[,2:ncol(rush.tbl)], 2, as.numeric)
            rb.names <- runner.names[!(runner.names %in% qb.names)]
        }
        for(qb.name in qb.names) {
            print(qb.name)
            pass.tbl.qb <- droplevels(subset(pass.tbl, QB==qb.name))
            rush.tbl.qb <- droplevels(subset(rush.tbl, Runner==qb.name))
            if(nrow(rush.tbl.qb)==0) {
                rush.tbl.qb[1,] <- 0
                rush.tbl.qb[,is.na(rush.tbl.qb)] <- 0
            }
            if(!(qb.name %in% names(qb.list))) {
                qb.list[[qb.name]] <- data.frame("game.num"=1,
                                                 "cum.pass.atts"=0,
                                                 "cum.comps"=0,
                                                 "cum.pass.yds"=0,
                                                 "cum.pass.tds"=0,
                                                 "cum.ints"=0,
                                                 "cum.carries"=0,
                                                 "cum.rush.yds"=0,
                                                 "cum.rush.tds"=0)
            } else {
                qb.list[[qb.name]]$game.num <- qb.list[[qb.name]]$game.num + 1
            }
            qb.list[[qb.name]]$cum.pass.atts <- qb.list[[qb.name]]$cum.pass.atts + pass.tbl.qb$ATT
            qb.list[[qb.name]]$cum.comps <- qb.list[[qb.name]]$cum.comps + pass.tbl.qb$CMP
            qb.list[[qb.name]]$cum.pass.yds <- qb.list[[qb.name]]$cum.pass.yds + pass.tbl.qb$YDS
            qb.list[[qb.name]]$cum.pass.tds <- qb.list[[qb.name]]$cum.pass.tds + pass.tbl.qb$TD
            qb.list[[qb.name]]$cum.ints <- qb.list[[qb.name]]$cum.ints + pass.tbl.qb$INT
            qb.list[[qb.name]]$cum.carries <- qb.list[[qb.name]]$cum.carries + rush.tbl.qb$CAR
            qb.list[[qb.name]]$cum.rush.yds <- qb.list[[qb.name]]$cum.rush.yds + rush.tbl.qb$YDS
            qb.list[[qb.name]]$cum.rush.tds <- qb.list[[qb.name]]$cum.rush.tds + rush.tbl.qb$TD

            qb.game <- data.frame("qb"=qb.name,
                                "year"=year,
                                "game.num"=qb.list[[qb.name]]$game.num,
                                "opponent"=opp,
                                "pass.atts"=pass.tbl.qb$ATT,
                                "comps"=pass.tbl.qb$CMP,
                                "pass.yds"=pass.tbl.qb$YDS,
                                "pass.tds"=pass.tbl.qb$TD,
                                "ints"=pass.tbl.qb$INT,
                                "carries"=rush.tbl.qb$CAR,
                                "rush.yds"=rush.tbl.qb$YDS,
                                "rush.tds"=rush.tbl.qb$TD)
            qb.df <- cbind(qb.game, qb.list[[qb.name]][,-1])
            qb.stats <- rbind(qb.stats, qb.df)
        }

        for(rb.name in rb.names) {
            print(rb.name)
            rush.tbl.rb <- droplevels(subset(rush.tbl, Runner==rb.name))
            if(!(rb.name %in% names(rb.list))) {
                rb.list[[rb.name]] <- data.frame("game.num"=1,
                                                 "cum.carries"=0,
                                                 "cum.rush.yds"=0,
                                                 "cum.rush.tds"=0)
            } else {
                rb.list[[rb.name]]$game.num <- rb.list[[rb.name]]$game.num + 1
            }
            rb.list[[rb.name]]$cum.carries <- rb.list[[rb.name]]$cum.carries + rush.tbl.rb$CAR
            rb.list[[rb.name]]$cum.rush.yds <- rb.list[[rb.name]]$cum.rush.yds + rush.tbl.rb$YDS
            rb.list[[rb.name]]$cum.rush.tds <- rb.list[[rb.name]]$cum.rush.tds + rush.tbl.rb$TD

            rb.game <- data.frame("rb"=rb.name,
                                  "year"=year,
                                  "game.num"=rb.list[[rb.name]]$game.num,
                                  "opponent"=opp,
                                  "carries"=rush.tbl.rb$CAR,
                                  "rush.yds"=rush.tbl.rb$YDS,
                                  "rush.tds"=rush.tbl.rb$TD)
            rb.df <- cbind(rb.game, rb.list[[rb.name]][,-1])
            rb.stats <- rbind(rb.stats, rb.df)
        }
        done.links <- c(done.links, game.link)
    }
}

save(qb.list, file="~/Documents/R_musings/UO_stats/oregon_qb_stats_list")
write.table(qb.stats,
            file="~/Documents/R_musings/UO_stats/oregon_qb_stats.txt",
            sep="\t",
            quote=T,
            row.names=F)
save(rb.list, file="~/Documents/R_musings/UO_stats/oregon_rb_stats_list")
write.table(rb.stats,
            file="~/Documents/R_musings/UO_stats/oregon_rb_stats.txt",
            sep="\t",
            quote=T,
            row.names=F)
save(done.links, file="~/Documents/R_musings/UO_stats/oregon_game_stats_links")
