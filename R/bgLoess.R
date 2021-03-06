bgLoess <-
function( bgfiles, lspan=0.05, threads=getOption("threads",1L), omitY=FALSE, omitM=FALSE, mbg=FALSE){

	# assumes sorted bg

	bgnames <- basename(removeext(bgfiles))
	numbgs <- length(bgfiles)
	outnames <- paste(bgnames,"_loess",gsub("\\.","-",lspan),".bg",sep="")
	chromthreads <- floor(threads/numbgs)
	if(chromthreads==0){chromthreads=1}

	dump <- mclapply(seq_len(numbgs), function(x){
		curbg <- read_tsv ( bgfiles[x], col_names=mbg )
		if(mbg){columnnames=colnames(curbg)}

		if(omitY){curbg=curbg[which(curbg[,1]!="chrY"),]}
		if(omitM){curbg=curbg[which(curbg[,1]!="chrM"),]}

		#curbg$V4[is.infinite(curbg$V4)]<-NA

		chroms    <- unique(curbg[,1])
		numchroms <- length(chroms)

		pointsperchrom <- as.numeric(table(curbg[,1]))
		pointratios    <-	max(pointsperchrom)/pointsperchrom
		scaledspans    <- lspan*pointratios

		smoothstats <- data.frame( chr=chroms , numPoints=pointsperchrom , scaledSpans=scaledspans)

		if(getOption("verbose")){print(paste("smoothing stats for",bgnames[x]));print(smoothstats)}
		all=split(curbg,curbg[,1])

		lscores<-mclapply(1:numchroms,function(i){
			cur <- all[[i]]

			cura <- lapply(4:ncol(cur), function(k){
				cur[,k] <- tryCatch(
					{
						loess(cur[,k]~cur[,2],span=scaledspans[i])$fitted

					},
					warning = function(war){
						print(paste("warning for file",bgnames[x],"chromosome",cur[1,1],":",war))
						out <- loess(cur[,k]~cur[,2],span=scaledspans[i])$fitted
						return(out)
					},
					error = function(err){
						print(paste("smoothing failed for file",bgnames[x],"chromosome",cur[1,1],":",err))
						return(cur[,k])
					}
				)
			})
			cura <- as.data.frame(cura)
			colnames(cura) <- columnnames[-(1:3)]
			cura <- cbind(cur[,1:3],cura)
			#print(str(cura))

			return(cura)
		},mc.cores=chromthreads, mc.preschedule=FALSE)
		print(str(lscores))
		curbg<-do.call(rbind,lscores)
		tsvWrite(curbg,file=outnames[x],col_names=mbg)
		rm(curbg)
		gc()

	}, mc.cores=threads, mc.preschedule=FALSE)

	return(outnames)

	#chroms<-mixedsort(chroms)
	#cat(bgname,": reference chromosome for span will be",chroms[1],"\n")
	#pointsperchrom<-unlist(lapply(1:numchroms, function(x) nrow(curbg[which(curbg$V1==chroms[x]),])))

	#})

	# lscores<-mclapply(1:numchroms, function(i){
	# 	curchrom<-curbg[which(curbg$V1==chroms[i]),]
	# 	if(i==1){clspan=lspan} else{clspan=lspan*(pointsperchrom[i]/pointsperchrom[1])}
	# 	goodpoints<-which(complete.cases(curchrom[,4]))
	# 	y<-curchrom[goodpoints,4]
	# 	x<-curchrom[goodpoints,2]
	# 	curchrom[goodpoints,4]<-loess(y~x,span=clspan)$fitted
	# 	curchrom
	# },mc.cores=cores,mc.preschedule=FALSE)
	#curbg<-curbg[order(curbg$V1,curbg$V2),]

}
