


#Takes variants and plots the frequencies of any two samples from the same individual against each other.
#Goes to some effort in marking interesting SNVs.
makeScatterPlots = function(variants, samplePairs, timePoints, plotDirectory, genome='hg19', cpus=1, plotPDF=F, forceRedo=F) {
  scatterDirectory = paste0(plotDirectory, '/scatters')
  if ( !file.exists(scatterDirectory) ) dir.create(scatterDirectory)
  for ( pair in samplePairs ) {
    dir1 = paste0(scatterDirectory, '/', pair[1])
    if ( !file.exists(dir1) ) dir.create(dir1)
    dir2 = paste0(dir1, '/', pair[2])
    if ( !file.exists(dir2) | forceRedo ) {
      if ( !file.exists(dir2) ) dir.create(dir2)
      boring = variants$variants[[pair[1]]]$var == 0 & variants$variants[[pair[2]]]$var == 0
      q1 = variants$variants[[pair[1]]][!boring,]
      q2 = variants$variants[[pair[2]]][!boring,]

      if ( !('inGene' %in% names(q1)) ) {
        warning('importing gene names from SNPs in scatter plots')
        q1$inGene = variants$SNPs[as.character(q1$x),]$inGene
        q2$inGene = variants$SNPs[as.character(q2$x),]$inGene
      }
      
      ps=vafScatter(q1, q2, cpus=cpus, verbose=F, doPlot=F, maxVariants=500e3)
      psuf=vafScatter(q1, q2, cpus=cpus, plotFlagged=F, verbose=F, doPlot=F, maxVariants=500e3)

      if ( plotPDF ) {
        outfile = paste0(dir2, '/all.pdf')
        catLog('Plotting to', outfile, '\n')
        pdf(outfile, width = 10, height=10)
      }
      else {
        outfile = paste0(dir2, '/all.png')
        catLog('Plotting to', outfile, '\n')
        png(outfile, width = 10, height=10, res=300, units='in')
      }
      vafScatter(q1, q2, verbose=F, ps=psuf, plotFlagged=F, genome=genome, maxVariants=500e3,
                     main=paste0('clean variants: ', pair[1], ' vs ', pair[2]),
                     xlab=paste0('variant frequency for ', pair[1], ' (', timePoints[pair[1]], ')'),
                     ylab=paste0('variant frequency for ', pair[2], ' (', timePoints[pair[2]], ')'), cpus=1)
      dev.off()
      
      if ( plotPDF ) {
        outfile = paste0(dir2, '/allNamed.pdf')
        pdf(outfile, width = 10, height=10)
      }
      else {
        outfile = paste0(dir2, '/allNamed.png')
        png(outfile, width = 10, height=10, res=300, units='in')
      }
      vafScatter(q1, q2, verbose=F, ps=psuf, plotFlagged=F, genome=genome, maxVariants=500e3,
                     main=paste0('clean variants: ', pair[1], ' vs ', pair[2]),
                     xlab=paste0('variant frequency for ', pair[1], ' (', timePoints[pair[1]], ')'),
                     ylab=paste0('variant frequency for ', pair[2], ' (', timePoints[pair[2]], ')'), cpus=1,
                     print=T, printRedCut=0.25)
      dev.off()

      if ( plotPDF ) {
        outfile = paste0(dir2, '/allFlagged.pdf')
        pdf(outfile, width = 10, height=10)
      }
      else {
        outfile = paste0(dir2, '/allFlagged.png')
        png(outfile, width = 10, height=10, res=300, units='in')
      }
      vafScatter(q1, q2, verbose=F, ps=ps, genome=genome, maxVariants=500e3,
                     main=paste0('all variants: ', pair[1], ' vs ', pair[2]),
                     xlab=paste0('variant frequency for ', pair[1], ' (', timePoints[pair[1]], ')'),
                     ylab=paste0('variant frequency for ', pair[2], ' (', timePoints[pair[2]], ')'), cpus=1)
      dev.off()
      
      catLog('Now by chromsome. Preparing..')
      chrs = xToChr(q1$x, genome=genome)
      catLog('done!\n  Plotting chr:')
      for ( chr in names(chrLengths(genome)) ) {
        use = chrs == chr
        if ( sum(use) == 0 ) next
        if ( plotPDF ) {
          outfile = paste0(dir2, '/chr', chr, '.pdf')
          pdf(outfile, width = 10, height=10)
        }
        else {
          outfile = paste0(dir2, '/chr', chr, '.png')
          png(outfile, width = 10, height=10, res=144, units='in')
        }
        catLog(chr, '..', sep='')
        vafScatter(q1[use,], q2[use,], genome=genome, maxVariants=50e3,
                       main=paste0('all variants: ', pair[1], ' vs ', pair[2], ', chr', chr),
                       xlab=paste0('variant frequency for ', pair[1], ' (', timePoints[pair[1]], ')'),
                       ylab=paste0('variant frequency for ', pair[2], ' (', timePoints[pair[2]], ')'), cpus=1, print=T,
                       printRedCut=0.25, plotPosition=T, verbose=F)
        dev.off()
      }
      catLog('done!\n')
    }
  }
}


#' plots a scatter of the VAF between two samples
#'
#' @param q1 data.frame. The variants of the x sample, taken from the loaded data$allVariants$variants$variants$mySample
#' @param q2 data.frame. The variants of the y sample, taken from the loaded data$allVariants$variants$variants$mySample
#' @param ps numeric. p-values of the variants. Default NA calculates them, but supplying them directly can save time.
#' @param covScale numeric. The coverage where the point size is one. Larger coverage scale will make the points smaller. Default 100.
#' @param maxCex numeric. Cutoff for maximum point size. Default 1.5.
#' @param minCov numeric. Variants with coverage below this level are not plotted.
#' @param plotFlagged logical. If flagged variants shouldbe plotted. Default T.
#' @param cpus numeric. The maximum number of cpus to run on.
#' @param verbose logical. If some diagnostic outputs should be printed to terminal. Default T.
#' @param print logical. If gene names of significantly different VAFs should be printed on the plot. Default F.
#' @param printRedCut numeric. The redness (0 to 1) above which gene names are printed if print is TRUE. Default 0.99.
#' @param printOnlyNovel logical. Only print gene names if the VAF is small in one sample if print is TRUE. Default FALSE.
#' @param plotPosition logical. Show the genomic position of each variant with a thin line to the top of the plot, as well as colour coding. Default FALSE.
#' @param genome character. The genome aligned to. Default 'hg19'.
#' @param outputHighlighted logical. Prints the printed genes to terminal. Default FALSE.
#' @param legend logical. If the legend should be included. Default TRUE.
#' @param redCut numeric. Sets how significantly different the VAFs have to be fo the dot to be coloured red. Default 0.75.
#' @param forceCol colour. Forces all the dots to this colour. Default NA does colour by significance.
#' @param add logical. If TRUE, the dots are added to the existing plot. Default FALSE.
#' @param GoI character. vector of genes of interest that always get their gene name printed on the plot. Default c().
#' @param printCex numeric. A scaling factor for the size of the printed gene names. Default 1.
#' @param doPlot numeric. If FALSE, the plot isn't made, but p values are returned. Default TRUE.
#' @param minSomaticP numeric. Variants with a somaticP below this cut in both samples are excluded. Default 0 includes all points.
#' @param ignoreFlagsInOne character. Variants with this flag in one (but not both) sample are plotted even if plotFlagged is FALSE. Default c('Svr', 'Mv', 'Nab').
#' @param ignoreFlagsInBoth character. Variants with this flag are plotted even if plotFlagged is FALSE. Default c('Srr').
#' @param flagOpacity numeric. The opacity of the flagged variants. Default 0.4.
#' @param severityWidth numeric. A scaling factor for the size of the orange circle for protein altering SNVs. Default 0.5.
#' @param cosmicWidth numeric. A scaling factor for the size of the green circle around COSMIC census genes. Default 3.
#' @param ...  remaining arguments are passed to plot(...)
#'
#' @details This function is a wrapped for the base heatmap() function. It got nicer default colours, doesn't normalise rows or columns by deafult, and has some support for differential expression data. Also prints a colour scale at the side.
#'
#'
#' @export
#' @examples
#' #random matrix to plot, centered around 0. Plot in 'DE' colours.
#' mx = matrix(rt(400, df=10), nrow=100)
#' makeHeatmap(mx, col='DE')
#' 
#' #random matrix to plot, between 0 and 1. Plot in default and sunset colours.
#' mx = matrix(runif(400), nrow=100)
#' makeHeatmap(mx)
#' makeHeatmap(mx, col='sunset')
#'
qualityScatter = function(q1, q2, ps = NA, covScale=100, maxCex=1.5, minCov=10, main='', xlab='variant frequency: sample1', ylab='variant frequency: sample2', plotFlagged=T, cpus=1, verbose=T, print = F, printRedCut = 0.99, printOnlyNovel=F, plotPosition=F, genome='hg19', xlim=c(0,1), ylim=c(0,1), outputHighlighted=F, frame.plot=F, legend=T, redCut=0.75, forceCol=NA, add=F, GoI=c(), printCex=1, doPlot=T, minSomaticP=0, ignoreFlagsInOne = c('Svr', 'Mv', 'Nab'), ignoreFlagsInBoth = c('Srr'), flagOpacity=0.4, severityWidth=0.5, cosmicWidth=3, ...) {
  if ( !exists('catLog') ) assign('catLog', cat, envir=.GlobalEnv)
  sharedRows = intersect(rownames(q1), rownames(q2))
  q1 = q1[sharedRows,]
  q2 = q2[sharedRows,]

  use = q1$var > 0 | q2$var > 0
  q1 = q1[use,]
  q2 = q2[use,]

  if ( minSomaticP > 0 & 'somaticP' %in% names(q1) & 'somaticP' %in% names(q2)  ) {
    use = pmax(q1$somaticP, q2$somaticP) >= minSomaticP
    q1 = q1[use,]
    q2 = q2[use,]    
  }
  
  freq1 = q1$var/q1$cov
  freq1[is.na(freq1)] = -0.02
  freq2 = q2$var/q2$cov
  freq2[is.na(freq2)] = -0.02

  q1$cov = q1$var + q1$ref
  q2$cov = q2$var + q2$ref

  q1$start = q1$end = xToPos(q1$x, genome=genome)
  q1$chr = xToChr(q1$x, genome=genome)
  
  db = q1$db
  flag1 = q1$flag
  flag2 = q2$flag

  #remove a few flags if only present in one sample
  for ( flagToCheck in ignoreFlagsInOne ) {
    flagIn1 = grepl(flagToCheck, flag1) & !grepl(flagToCheck, flag2) & freq2 > 0
    flag1[flagIn1] = gsub(flagToCheck, '', flag1[flagIn1])
    flagIn2 = grepl(flagToCheck, flag2) & !grepl(flagToCheck, flag1) & freq1 > 0
    flag2[flagIn2] = gsub(flagToCheck, '', flag2[flagIn2])
  }
  #remove flags entirely
  for ( flagToCheck in ignoreFlagsInBoth ) {
    flag1 = gsub(flagToCheck, '', flag1)
    flag2 = gsub(flagToCheck, '', flag2)
  }
  
  clean = flag1 == '' & flag2 == ''
  
  if ( verbose ) catLog(sum(clean), 'out of', nrow(q1), 'non-zero variants are not flagged!\n')

  if ( !plotFlagged ) {
    q1 = q1[clean,]
    q2 = q2[clean,]
    freq1 = q1$var/q1$cov
    freq1[is.na(freq1)] = -0.02
    freq2 = q2$var/q2$cov
    freq2[is.na(freq2)] = -0.02
    x = as.character(q1$x)
    db = q1$db
    clean = rep(T, nrow(q1))
  }

  if ( is.na(ps[1]) ) {
    doP = which(q1$cov >= max(1, minCov) & q2$cov >= max(1, minCov))
    if ( cpus == 1 )
      psCov = sapply(doP, function(i) fisher.test(matrix(c(q1$ref[i], q1$var[i], q2$ref[i], q2$var[i]), nrow=2))$p.value)
    else {
      psCov = unlist(mclapply(doP, function(i)
        fisher.test(matrix(c(q1$ref[i], q1$var[i], q2$ref[i], q2$var[i]), nrow=2))$p.value, mc.cores=cpus))
    }
    ps = rep(1, nrow(q1))
    ps[doP] = psCov
    names(ps) = rownames(q1)
  }
  dof = max(20, sum(clean & freq1+freq2 > 0 & freq1+freq2 < 2))
  if ( verbose ) catLog('MHC done with effective dof', dof, '\n')
  red = pmin(1, pmax(0, (-log10(ps)/log10(dof) - redCut)))
  if ( any(is.na(red)) ) {
    red[is.na(red)] = 0
    warning('Got NA red colour in scatter.')
  }
  if ( any(is.na(db)) ) {
    db[is.na(db)] = 0
    warning('Got NA db in scatter.')
  }

  use = q1$cov >= minCov & q2$cov >= minCov
  if ( any(is.na(use)) ) {
    warning(paste0(sum(is.na(use)), ' NA entries in use'))
    use = use & !is.na(use)
  }
  if ( sum(use) == 0 ) invisible(ps)
  cleanOrder = which(clean&use)[order((red-0.1*db)[clean&use])]
  col = rep('black', length(red))
  col[!clean&use] =
    rgb((1-flagOpacity) + red[!clean&use]*flagOpacity,
        (1-flagOpacity)+red[!clean&use]*flagOpacity/2,
        (1-flagOpacity))
  col[clean&use] = rgb(red,0,ifelse(db, 0,(1-red)))[clean&use]
  if ( !is.na(forceCol[1]) & length(forceCol) != length(col) ) col = rep(forceCol[1], length(col))
  if ( !is.na(forceCol[1]) & length(forceCol) == length(col) ) col = forceCol
  cex = pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)/covScale))
  if ( 'germline' %in% names(q1) ) pch = ifelse(clean, ifelse(db, 4, ifelse(q1$germline & !is.na(q1$germline), 3, 19)), ifelse(db, 4, 1))
  else pch = ifelse(clean, ifelse(db, 4, 19), ifelse(db, 4, 1))
  if ( !add & doPlot ) {
    plot(1, type='n', xlim=xlim, ylim=ylim, xlab = xlab, ylab = ylab, main=main, frame.plot=frame.plot, ...)
    segments(c(0,1,0,0,0, 0.5, 0), c(0,0, 0,1,0, 0, 0.5), c(0, 1, 1, 1, 1, 0.5, 1), c(1, 1, 0, 1, 1, 1, 0.5), col = rgb(0.8, 0.8, 0.8), lwd=0.3)
  }
  if ( !plotPosition & doPlot ) {
    if ( legend & !add ) {
      if ( plotFlagged )
        legend('bottomright', c('clean non-db', 'flagged non-db', 'clean germline-like non-db', 'clean db', 'flagged db', 'significantly different', 'high coverage', 'low coverage', 'protein altering', 'COSMIC Census Gene'), pch=c(19, 1, 3, 4, 4, 19, 19, 19, 1, 1), col=c('blue', 'grey', 'blue', 'black', 'grey', 'red', 'black', 'black', 'orange', 'green'), pt.cex=c(1,1,1,1,1,1,1,0.3, 1.5, 2), pt.lwd=c(1,1,1,1,1,1,1,1, 2, 4), bg='white')
      else
        legend('bottomright', c('not in dbSNP', 'in dbSNP', 'germline-like non-db', 'significantly different', 'low coverage', 'protein altering', 'COSMIC Census Gene'), pch=c(19, 4, 3, 19, 19, 1, 1), col=c('blue', 'black', 'blue', 'red', 'black', 'orange', 'green'), pt.cex=c(1,1,1,1,0.3, 1.5, 2), pt.lwd=c(1,1,1,1,1, 2, 4), bg='white')
    }
    points(freq1[!clean&use], freq2[!clean&use], cex=cex[!clean&use],
           lwd=pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)[!clean&use]/covScale)), pch=pch[!clean&use], col=col[!clean&use])
    points(freq1[cleanOrder], freq2[cleanOrder], cex=cex[cleanOrder],
           lwd=pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)[cleanOrder]/covScale)), pch=pch[cleanOrder], col=col[cleanOrder])
  }

  if ( 'severity' %in% names(q1) & 'severity' %in% names(q2) & doPlot ) {
    severity = pmin(q1$severity, q2$severity)
    severe = clean & use & severity <= 11 & (!db | (!q1$dbValidated | is.na(q1$dbValidated)) | (q1$dbMAF < 0.01 | is.na(q1$dbMAF)))
    points(freq1[severe], freq2[severe], cex=cex[severe]+(12-severity[severe])/10,
           lwd=(12-severity[severe])*severityWidth, pch=1, col='orange')
    if ( 'isCosmicCensus' %in% names(q1) & 'isCosmicCensus' %in% names(q2) ) {
      isCosmic = (q1$isCosmicCensus | q2$isCosmicCensus) & severe
      points(freq1[isCosmic], freq2[isCosmic], cex=cex[isCosmic]+(12-severity[isCosmic])/10+1,
             lwd=cosmicWidth, pch=1, col='green')
    }
  }
  
  if ( plotPosition & doPlot ) {
    segCex = pmin(1,(cex^2/7*abs((freq1+freq2)*(2-freq1-freq2))))
    segCex[freq1 < 0 | freq2 < 0] = 0
    pos = q1$start/chrLengths(genome)[as.character(q1$chr)]
    col = rgb(pmin(1,pmax(0, 1-abs(3*pos-0.5))), pmin(1,pmax(0, 1-abs(3*pos-1.5))), pmin(1,pmax(0, 1-abs(3*pos-2.5))), segCex)
    col[!clean] = rgb(0.5, 0.5, 0.5, segCex[!clean])
    lty = ifelse(use, ifelse(clean, 1, 2), 0)
    segments(freq1[!clean&use], freq2[!clean&use], pos[!clean&use], rep(1.02,sum(!clean&use)), lwd=segCex[!clean&use],
             col=col[!clean&use], lty=lty[!clean&use])
    segments(freq1[clean&use], freq2[clean&use], pos[clean&use], rep(1.02, sum(clean&use)), lwd=segCex[clean&use],
             col=col[clean&use], lty=lty[clean&use])
    col = rgb(pmin(1,pmax(0, 1-abs(3*pos-0.5))), pmin(1,pmax(0, 1-abs(3*pos-1.5))), pmin(1,pmax(0, 1-abs(3*pos-2.5))))
    col[!clean&use] = rgb(0.5, 0.5, 0.5)
    points(freq1[!clean&use], freq2[!clean&use], cex= cex[!clean&use], pch=pch[!clean&use], col = col[!clean&use])
    points(freq1[clean&use], freq2[clean&use], cex= cex[clean&use], pch=pch[clean&use], col = col[clean&use])
    points(pos[!clean&use], rep(1.02, length(pos[!clean&use])), pch=16, cex=0.5, col=col[!clean&use])
    points(pos[clean&use], rep(1.02, length(pos[clean&use])), pch=16, cex=0.5, col=col[clean&use])
    text(1.02, 1.02, 'SNPs')
  }

  if ( print & doPlot ) {
    toPrint = red > printRedCut
    if ( 'severity' %in% names(q1) & 'severity' %in% names(q2) ) {
      severity = pmin(q1$severity, q2$severity)
      severe = clean & use & severity <= 11 & (!db | (!q1$dbValidated | is.na(q1$dbValidated)) | (q1$dbMAF < 0.01 | is.na(q1$dbMAF)))
      if ( 'isCosmicCensus' %in% names(q1) & 'isCosmicCensus' %in% names(q2) ) {
        isCosmic = (q1$isCosmicCensus | q2$isCosmicCensus) & severe
        toPrint = toPrint | isCosmic
        col[isCosmic] = 'darkgreen'
        cex[isCosmic] = pmax(1.5, 1.5*cex[isCosmic])
      }
    }
    if ( length(GoI) > 0 )
      toPrint = toPrint | q1$inGene %in% GoI
    if ( printOnlyNovel ) toPrint = toPrint & freq1 < 0.1 & freq2 > 0.2
    if ( sum(toPrint) > 0 ) {
      printNames = gsub('.+:', '', q1[toPrint,]$inGene)
      printNames[is.na(printNames)] = 'i'
      if ( length(toPrint) > 0 )
        text(freq1[toPrint], freq2[toPrint] + 0.015*pmax(0.6, cex[toPrint]), printNames, col = col[toPrint], cex = pmax(0.6, cex[toPrint])*printCex)
      if ( 'isCosmicCensus' %in% names(q1) & 'isCosmicCensus' %in% names(q2) ) {
        isCosmic = (q1$isCosmicCensus | q2$isCosmicCensus) & severe
        if ( any(isCosmic) )
          text(freq1[isCosmic], freq2[isCosmic] + 0.015*pmax(0.6, cex[isCosmic]), printNames[isCosmic[which(toPrint)]],
               col = col[isCosmic], cex = pmax(0.6, cex[isCosmic])*printCex)
      }
      if ( verbose ) catLog('Highlighting', length(unique(printNames)), 'genes.\n')
      if ( outputHighlighted ) {
        out = data.frame('chr'=q1[toPrint,]$chr, 'pos'=q1[toPrint,]$start, 'x'=q1[toPrint,]$x, 'var'=q1$variant[toPrint], 'gene'=printNames,
          'f1'=freq1[toPrint], 'f2'=freq2[toPrint])
        print(out)
      }
    }
  }
  
  invisible(ps)
}




makeCloneScatterPlots = function(variants, stories, samplePairs, individuals, timePoints, plotDirectory, genome='hg19', cpus=1, forceRedo=F) {
  scatterDirectory = paste0(plotDirectory, '/scatters')
  if ( !file.exists(scatterDirectory) ) dir.create(scatterDirectory)
  for ( pair in samplePairs ) {
    dir1 = paste0(scatterDirectory, '/', pair[1])
    if ( !file.exists(dir1) ) dir.create(dir1)
    dir2 = paste0(dir1, '/', pair[2])
    outfile = paste0(dir2, '/clones.png')
    if ( !file.exists(outfile) | forceRedo ) {
      if ( !file.exists(dir2) ) dir.create(dir2)
      boring = variants$variants[[pair[1]]]$var == 0 & variants$variants[[pair[2]]]$var == 0
      q1 = variants$variants[[pair[1]]][!boring,]
      q2 = variants$variants[[pair[2]]][!boring,]
      
      somatics = (q1$somaticP > 0.1 | q2$somaticP > 0.1) & (!q1$germline | is.na(q1$germline))
      q1 = q1[somatics,]
      q2 = q2[somatics,]

      individual = individuals[pair[1]]
      storyCluster = stories[[individual]]$consistentClusters
      keptMutations = unlist(storyCluster$storyList)
      if ( 'germline' %in% names(storyCluster$storyList) )
        keptMutations = unlist(storyCluster$storyList[names(storyCluster$storyList) != 'germline'])
      keepVariants = rownames(q1)[rownames(q1) %in% keptMutations]
      q1 = q1[keepVariants,]
      q2 = q2[keepVariants,]

      if ( !('inGene' %in% names(q1)) ) {
        warning('importing gene names from SNPs in clone scatter')
        q1$inGene = variants$SNPs[as.character(q1$x),]$inGene
        q2$inGene = variants$SNPs[as.character(q2$x),]$inGene
      }
      
      col = rep('grey', nrow(q1))
      clones = clonesInTree(storyCluster$cloneTree)
      cloneCols = cloneToCol(storyCluster$cloneTree)$usedCols
      for ( clone in clones ) {
        col[rownames(q1) %in% storyCluster$storyList[[clone]]] = cloneCols[clone]
      }
      
      catLog('Plotting clone scatter to', outfile, '\n')
      png(outfile, width = 10, height=10, res=300, units='in')
      vafScatter(q1, q2, verbose=F, forceCol=col,
                     main=paste0('somatic variants: ', pair[1], ' vs ', pair[2]), legend=F,
                     xlab=paste0('variant frequency for ', pair[1], ' (', timePoints[pair[1]], ')'),
                     ylab=paste0('variant frequency for ', pair[2], ' (', timePoints[pair[2]], ')'), cpus=cpus)
      dev.off()
      catLog('done!\n')
    }
  }
}
























#' plots a scatter of the VAF between two samples
#'
#' @param q1 data.frame. The variants of the x sample, taken from the loaded data$allVariants$variants$variants$mySample
#' @param q2 data.frame. The variants of the y sample, taken from the loaded data$allVariants$variants$variants$mySample
#' @param ps numeric. p-values of the variants. Default NA calculates them, but supplying them directly can save time.
#' @param covScale numeric. The coverage where the point size is one. Larger coverage scale will make the points smaller. Default 100.
#' @param maxCex numeric. Cutoff for maximum point size. Default 1.5.
#' @param minCov numeric. Variants with coverage below this level are not plotted.
#' @param plotFlagged logical. If flagged variants shouldbe plotted. Default T.
#' @param cpus numeric. The maximum number of cpus to run on.
#' @param verbose logical. If some diagnostic outputs should be printed to terminal. Default T.
#' @param print logical. If gene names of significantly different VAFs should be printed on the plot. Default F.
#' @param printRedCut numeric. The redness (0 to 1) above which gene names are printed if print is TRUE. Default 0.99.
#' @param printOnlyNovel logical. Only print gene names if the VAF is small in one sample if print is TRUE. Default FALSE.
#' @param plotPosition logical. Show the genomic position of each variant with a thin line to the top of the plot, as well as colour coding. Default FALSE.
#' @param genome character. The genome aligned to. Default 'hg19'.
#' @param outputHighlighted logical. Prints the printed genes to terminal. Default FALSE.
#' @param legend logical. If the legend should be included. Default TRUE.
#' @param redCut numeric. Sets how significantly different the VAFs have to be fo the dot to be coloured red. Default 0.75.
#' @param forceCol colour. Forces all the dots to this colour. Default NA does colour by significance.
#' @param add logical. If TRUE, the dots are added to the existing plot. Default FALSE.
#' @param GoI character. vector of genes of interest that always get their gene name printed on the plot. Default c().
#' @param printCex numeric. A scaling factor for the size of the printed gene names. Default 1.
#' @param doPlot numeric. If FALSE, the plot isn't made, but p values are returned. Default TRUE.
#' @param minSomaticP numeric. Variants with a somaticP below this cut in both samples are excluded. Default 0 includes all points.
#' @param ignoreFlagsInOne character. Variants with this flag in one (but not both) sample are plotted even if plotFlagged is FALSE. Default c('Svr', 'Mv', 'Nab').
#' @param ignoreFlagsInBoth character. Variants with this flag are plotted even if plotFlagged is FALSE. Default c('Srr').
#' @param flagOpacity numeric. The opacity of the flagged variants. Default 0.4.
#' @param severityWidth numeric. A scaling factor for the size of the orange circle for protein altering SNVs. Default 0.5.
#' @param cosmicWidth numeric. A scaling factor for the size of the green circle around COSMIC census genes. Default 3.
#' @param ...  remaining arguments are passed to plot(...)
#'
#' @details This function takes two superFreq data frames of variants, and scatters the VAFs against each other.
#'
#'
#' @export
vafScatter = function(q1, q2, ps = NA, covScale=100, maxCex=1.5, minCov=10, main='', xlab='variant frequency: sample1', ylab='variant frequency: sample2', plotFlagged=T, cpus=1, verbose=T, print = F, printRedCut = 0.99, printOnlyNovel=F, plotPosition=F, genome='hg19', xlim=c(0,1), ylim=c(0,1), outputHighlighted=F, frame.plot=F, legend=T, redCut=0.75, forceCol=NA, add=F, GoI=c(), printCex=1, doPlot=T, minSomaticP=0, ignoreFlagsInOne = c('Svr', 'Mv', 'Nab'), ignoreFlagsInBoth = c('Srr'), flagOpacity=0.4, severityWidth=0.5, cosmicWidth=3, maxVariants=500e3, ...) {
  if ( !exists('catLog') ) assign('catLog', cat, envir=.GlobalEnv)

  #cut down to shared variants that are present in at least one sample.
  sharedRows = intersect(rownames(q1), rownames(q2))
  q1 = q1[sharedRows,]
  q2 = q2[sharedRows,]
  use = q1$var > 0 | q2$var > 0
  q1 = q1[use,]
  q2 = q2[use,]

  #restrict to only somatic variants if desired
  if ( minSomaticP > 0 & 'somaticP' %in% names(q1) & 'somaticP' %in% names(q2)  ) {
    use = pmax(q1$somaticP, q2$somaticP) >= minSomaticP
    q1 = q1[use,]
    q2 = q2[use,]    
  }

  flag1 = q1$flag
  flag2 = q2$flag
  freq1 = q1$var/q1$cov
  freq1[is.na(freq1)] = -0.02
  freq2 = q2$var/q2$cov
  freq2[is.na(freq2)] = -0.02

  #remove a few flags if only present in one sample
  for ( flagToCheck in ignoreFlagsInOne ) {
    flagIn1 = grepl(flagToCheck, flag1) & !grepl(flagToCheck, flag2) & freq2 > 0
    flag1[flagIn1] = gsub(flagToCheck, '', flag1[flagIn1])
    flagIn2 = grepl(flagToCheck, flag2) & !grepl(flagToCheck, flag1) & freq1 > 0
    flag2[flagIn2] = gsub(flagToCheck, '', flag2[flagIn2])
  }
  #remove others flags entirely
  for ( flagToCheck in ignoreFlagsInBoth ) {
    flag1 = gsub(flagToCheck, '', flag1)
    flag2 = gsub(flagToCheck, '', flag2)
  }
  clean = flag1 == '' & flag2 == ''
  if ( verbose ) catLog(sum(clean), 'out of', nrow(q1), 'non-zero variants are not flagged!\n')

  #remove flagged variants if desired
  if ( !plotFlagged ) {
    q1 = q1[clean,]
    q2 = q2[clean,]
    clean = rep(T, nrow(q1))
  }

  #if there are too many variants, subsample the non-somatic variants to speed things up.
  nonSom = q1$somaticP == 0 & q2$somaticP == 0
  if ( sum(nonSom) > maxVariants ) {
    warning('There are a total of ', nrow(q1), ' variants to VAF scatter plot. Im subsampling to ', maxVariants, ' non-somatic variants to speed things up.')
    #set the sampling seed for reproducibility
    set.seed(42)
    discard = sample(rownames(q1)[nonSom], sum(nonSom) - maxVariants)
    use = !(rownames(q1) %in% discard)
    q1 = q1[use,]
    q2 = q2[use,]
    flag1 = flag1[use]
    flag2 = flag2[use]
    clean = clean[use]
  }
  
  #precalculate some things
  freq1 = q1$var/q1$cov
  freq1[is.na(freq1)] = -0.02
  freq2 = q2$var/q2$cov
  freq2[is.na(freq2)] = -0.02
  q1$cov = q1$var + q1$ref
  q2$cov = q2$var + q2$ref
  q1$start = q1$end = xToPos(q1$x, genome=genome)
  q1$chr = xToChr(q1$x, genome=genome)
  db = q1$db

  #calculate p values from fisher test, MHC and convert to red hue for points.
  if ( is.na(ps[1]) ) {
    doP = which(q1$cov >= max(1, minCov) & q2$cov >= max(1, minCov))
    if ( cpus == 1 )
      psCov = sapply(doP, function(i) fisher.test(matrix(c(q1$ref[i], q1$var[i], q2$ref[i], q2$var[i]), nrow=2))$p.value)
    else {
      psCov = unlist(mclapply(doP, function(i)
        fisher.test(matrix(c(q1$ref[i], q1$var[i], q2$ref[i], q2$var[i]), nrow=2))$p.value, mc.cores=cpus))
    }
    ps = rep(1, nrow(q1))
    if ( length(doP) > 0 ) ps[doP] = psCov
    names(ps) = rownames(q1)
  }
  dof = max(20, sum(clean & freq1+freq2 > 0 & freq1+freq2 < 2))
  if ( verbose ) catLog('MHC done with effective dof', dof, '\n')
  red = pmin(1, pmax(0, (-log10(ps)/log10(dof) - redCut)))
  if ( any(is.na(red)) ) {
    red[is.na(red)] = 0
    warning('Got NA red colour in scatter.')
  }
  if ( any(is.na(db)) ) {
    db[is.na(db)] = F
    warning('Got NA db in scatter.')
  }

  #filter on coverage as desired
  use = q1$cov >= minCov & q2$cov >= minCov
  if ( any(is.na(use)) ) {
    warning(paste0(sum(is.na(use)), ' NA entries in use'))
    use = use & !is.na(use)
  }

  #return if no variants left
  if ( sum(use) == 0 ) invisible(ps)

  #set up colour based on dbSNP, flag and red hue.
  #order so that important variants (clean, red) are plotted on top.
  cleanOrder = which(clean&use)[order((red-0.1*db)[clean&use])]
  col = sapply(seq_along(red), function(i) {
    secondCol = 'black'
    if ( !db[i] ) secondCol = mcri('blue')
    alpha = 1
    if ( !clean[i] ) {
      alpha = flagOpacity
      secondCol = 'grey'
    }
    superFreq:::combineColours(mcri('red'), secondCol, red[i], 1-red[i], alpha=alpha)
  })
  if ( !is.na(forceCol[1]) & length(forceCol) != length(col) ) col = rep(forceCol[1], length(col))
  if ( !is.na(forceCol[1]) & length(forceCol) == length(col) ) col = forceCol

  #size from coverage
  cex = pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)/covScale))

  #point style from dbSNP or if clustered in the germline clone
  if ( 'germline' %in% names(q1) ) pch = ifelse(clean, ifelse(db, 4, ifelse(q1$germline & !is.na(q1$germline), 3, 19)), ifelse(db, 4, 1))
  else pch = ifelse(clean, ifelse(db, 4, 19), ifelse(db, 4, 1))

  #set up empty plot.
  if ( !add & doPlot ) {
    plot(1, type='n', xlim=xlim, ylim=ylim, xlab = xlab, ylab = ylab, main=main, frame.plot=frame.plot, ...)
    segments(c(0,1,0,0,0, 0.5, 0), c(0,0, 0,1,0, 0, 0.5), c(0, 1, 1, 1, 1, 0.5, 1), c(1, 1, 0, 1, 1, 1, 0.5), col = rgb(0.8, 0.8, 0.8), lwd=0.3)
  }

  #add legends and plot points (in that order so that all points are visible, on top of legend if needed).
  if ( !plotPosition & doPlot ) {
    if ( legend & !add ) {
      if ( plotFlagged )
        legend('bottomright', c('clean non-db', 'flagged non-db', 'clean germline-like non-db', 'clean db', 'flagged db', 'significantly different', 'high coverage', 'low coverage', 'protein altering', 'COSMIC Census Gene', 'ClinVar pathogenic', 'COSMIC + pathogenic'), pch=c(19, 1, 3, 4, 4, 19, 19, 19,1,1,2,2), col=mcri(c('blue', 'grey', 'blue', 'black', 'grey', 'red', 'black', 'black', 'darkred', 'cyan','cyan','orange')), pt.cex=c(1,1,1,1,1,1,1,0.3,1.5,2,2,2), pt.lwd=c(1,1,1,1,1,1,1,1,2,3,3,4), bg='white')
      else
        legend('bottomright', c('not in dbSNP', 'in dbSNP', 'germline-like non-db', 'significantly different', 'low coverage', 'protein altering', 'COSMIC Census Gene', 'ClinVar pathogenic', 'COSMIC + pathogenic'), pch=c(19, 4, 3, 19, 19, 1,1,2,2), col=mcri(c('blue', 'black', 'blue', 'red', 'black', 'darkred', 'cyan','cyan','orange')), pt.cex=c(1,1,1,1,0.3,1.5,2,2,2), pt.lwd=c(1,1,1,1,1,2,3,3,4), bg='white')
    }
    points(freq1[!clean&use], freq2[!clean&use], cex=cex[!clean&use],
           lwd=pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)[!clean&use]/covScale)), pch=pch[!clean&use], col=col[!clean&use])
    points(freq1[cleanOrder], freq2[cleanOrder], cex=cex[cleanOrder],
           lwd=pmin(maxCex, sqrt(sqrt(q1$cov*q2$cov)[cleanOrder]/covScale)), pch=pch[cleanOrder], col=col[cleanOrder])
  }

  #highlight protein changing variants, COMSIC sensus genes and clinvar variants.
  if ( 'severity' %in% names(q1) & 'severity' %in% names(q2) & doPlot ) {    
    severity = pmin(q1$severity, q2$severity)
    somaticP = pmax(q1$somaticP, q2$somaticP)
    severe = clean & use & severity <= 11 & somaticP > 0

    isClinvar = isPathogenic = rep(F, nrow(q1))
    if ( 'ClinVar_ClinicalSignificance' %in% names(q1) & 'ClinVar_ClinicalSignificance' %in% names(q2) ) {
      isClinvar = (q1$ClinVar_ClinicalSignificance != '' | q2$ClinVar_ClinicalSignificance  != '')
      #for some reason the pattern [,$] doesnt match end of string or comma.
      isPathogenic =
        grepl('[pP]athogenic,', paste0(q1$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic$', paste0(q1$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic$', paste0(q2$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic,', paste0(q2$ClinVar_ClinicalSignificance))
    }
    
    isCosmic = rep(F, nrow(q1))
    if ( 'isCosmicCensus' %in% names(q1) & 'isCosmicCensus' %in% names(q2) ) {
      isCosmic = (q1$isCosmicCensus | q2$isCosmicCensus) & severe
    }

    highlight = severe | isPathogenic
    colHL = mcri(ifelse(!highlight, 'white', ifelse(!isPathogenic & !isCosmic, 'darkred', ifelse(!isPathogenic, 'cyan', ifelse(isCosmic, 'orange', 'cyan')))))
    pchHL = ifelse(isPathogenic, 2, 1)
    cexHL = cex + ifelse(!highlight, 0, ifelse(!isPathogenic & !isCosmic, 0.1, ifelse(!isPathogenic, 0.7, ifelse(isCosmic, 1, 0.7))))
    lwdHL = ifelse(!highlight, 0, ifelse(!isPathogenic & !isCosmic, (13-severity)/5, ifelse(!isPathogenic, 3, ifelse(isCosmic, 4, 3))))

    plotOrder = order(lwdHL)
    plotOrder = plotOrder[lwdHL[plotOrder] > 0]
        
    points(freq1[plotOrder], freq2[plotOrder], cex=cexHL[plotOrder],
                 lwd=lwdHL[plotOrder], pch=pchHL[plotOrder], col=colHL[plotOrder])

  }

  #cross link to genomic position on the top of the plot if desired.
  if ( plotPosition & doPlot ) {
    segCex = pmin(1,(cex^2/7*abs((freq1+freq2)*(2-freq1-freq2))))
    segCex[freq1 < 0 | freq2 < 0] = 0
    pos = q1$start/chrLengths(genome)[as.character(q1$chr)]
    col = rgb(pmin(1,pmax(0, 1-abs(3*pos-0.5))), pmin(1,pmax(0, 1-abs(3*pos-1.5))), pmin(1,pmax(0, 1-abs(3*pos-2.5))), segCex)
    col[!clean] = rgb(0.5, 0.5, 0.5, segCex[!clean])
    lty = ifelse(use, ifelse(clean, 1, 2), 0)
    segments(freq1[!clean&use], freq2[!clean&use], pos[!clean&use], rep(1.02,sum(!clean&use)), lwd=segCex[!clean&use],
             col=col[!clean&use], lty=lty[!clean&use])
    segments(freq1[clean&use], freq2[clean&use], pos[clean&use], rep(1.02, sum(clean&use)), lwd=segCex[clean&use],
             col=col[clean&use], lty=lty[clean&use])
    col = rgb(pmin(1,pmax(0, 1-abs(3*pos-0.5))), pmin(1,pmax(0, 1-abs(3*pos-1.5))), pmin(1,pmax(0, 1-abs(3*pos-2.5))))
    col[!clean&use] = rgb(0.5, 0.5, 0.5)
    points(freq1[!clean&use], freq2[!clean&use], cex= cex[!clean&use], pch=pch[!clean&use], col = col[!clean&use])
    points(freq1[clean&use], freq2[clean&use], cex= cex[clean&use], pch=pch[clean&use], col = col[clean&use])
    points(pos[!clean&use], rep(1.02, length(pos[!clean&use])), pch=16, cex=0.5, col=col[!clean&use])
    points(pos[clean&use], rep(1.02, length(pos[clean&use])), pch=16, cex=0.5, col=col[clean&use])
    text(1.02, 1.02, 'SNPs')
  }

  #print gene names on teh plot if desired.
  if ( print & doPlot ) {
    toPrint = red > printRedCut

    severity = pmin(q1$severity, q2$severity)
    somaticP = pmax(q1$somaticP, q2$somaticP)
    severe = clean & use & severity <= 11 & somaticP > 0

    isClinvar = isPathogenic = rep(F, nrow(q1))
    if ( 'ClinVar_ClinicalSignificance' %in% names(q1) & 'ClinVar_ClinicalSignificance' %in% names(q2) ) {
      isClinvar = (q1$ClinVar_ClinicalSignificance != '' | q2$ClinVar_ClinicalSignificance  != '')
      isPathogenic =
        grepl('[pP]athogenic,', paste0(q1$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic$', paste0(q1$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic$', paste0(q2$ClinVar_ClinicalSignificance)) |
        grepl('[pP]athogenic,', paste0(q2$ClinVar_ClinicalSignificance))
    }
    
    isCosmic = rep(F, nrow(q1))
    if ( 'isCosmicCensus' %in% names(q1) & 'isCosmicCensus' %in% names(q2) ) {
      isCosmic = (q1$isCosmicCensus | q2$isCosmicCensus) & severe
    }

    highlight = severe | isPathogenic
    colHL = mcri(ifelse(!highlight, col, ifelse(!isPathogenic & !isCosmic, 'darkred', ifelse(!isPathogenic, 'cyan', ifelse(isCosmic, 'orange', 'cyan')))))

    pchHL = ifelse(isPathogenic, 2, 1)
    cexHL = cex + ifelse(!highlight, 0, ifelse(!isClinvar & !isCosmic, 0.3, ifelse(!isClinvar, 0.7, ifelse(isCosmic, 1, 0.7))))
    lwdHL = ifelse(!highlight, 0, ifelse(!isClinvar & !isCosmic, (13-severity)/5, ifelse(!isClinvar, 3, ifelse(isCosmic, 4, 3))))

    toPrint = toPrint | isCosmic | isClinvar

    printOrder = order(lwdHL)
    printOrder = printOrder[toPrint[printOrder]]

    if ( length(GoI) > 0 )
      toPrint = toPrint | q1$inGene %in% GoI
    if ( printOnlyNovel ) toPrint = toPrint & freq1 < 0.1 & freq2 > 0.2
    if ( sum(toPrint) > 0 ) {
      printNames = gsub('.+:', '', q1[printOrder,]$inGene)
      printNames[is.na(printNames)] = 'i'
      if ( length(toPrint) > 0 )
        text(freq1[printOrder], freq2[printOrder] + 0.015*pmax(0.6, cexHL[printOrder]), printNames, col = colHL[printOrder], cex = pmax(0.6, cexHL[printOrder])*printCex)
      if ( verbose ) catLog('Highlighting', length(unique(printNames)), 'genes.\n')
      if ( outputHighlighted ) {
        out = data.frame('chr'=q1[toPrint,]$chr, 'pos'=q1[toPrint,]$start, 'x'=q1[toPrint,]$x, 'var'=q1$variant[toPrint], 'gene'=printNames,
          'f1'=freq1[toPrint], 'f2'=freq2[toPrint])
        print(out)
      }
    }
  }
  
  invisible(ps)
}

