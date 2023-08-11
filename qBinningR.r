library(pracma)
library(data.table)
setDTthreads(threads = 8)


calcNos <- function(x,err_x){
  ## Function to generate the normalized order space (nos) in m/z dimension
  nos = c(diff(x),-255)/c(err_x)
  return(nos)}


calcNosConst <- function(x){
  ## Function to determine RT differences
  nos = c(diff(x),-255)
  return(nos)
}


critVal <- function(n,alpha){
  ## Function generating the critical mz difference using order statistics
  
  critVal <- 3.05037165842070*log(n)^(-0.4771864667153)
  return(critVal)
}


createIndex <- function(bin){
  ## Fast implementation of determining the length of each bin
  
  d_bin = c(diff(bin),1)
  
  if(sum(d_bin)==0){nPerbin = length(bin)
  nPerbin2 = rep(nPerbin,nPerbin)
  }else{
    
    nPerbin = (1:length(bin))[d_bin==1]
    nPerbin = c(nPerbin[1],diff(nPerbin))
    nPerbin2 = rep(nPerbin ,nPerbin )           
  }
  
  return(list(nPerbin2,nPerbin))    
}


mz_later_split <- function(dt,alpha,minBinsize,lookup){
  ## Function looking for normalized order spaces bigger the critical value
  
  dt <- dt[order(dt$ID,dt$mz),]
  bin_mz <- T
  
  while(bin_mz){
    
    pm <-  dt[ ,list(n=length(mz),mean_err_mz = mean(err_mz)), by=ID]
    
    nPerbin <- rep(pm$n,pm$n)
    mean_err_mz <- rep(pm$mean_err_mz,pm$n)
    dt$nos <- calcNos(x = dt$mz,err_x = mean_err_mz)
    dt$nos[which(diff(dt$ID)!=0)] <- -255
    dt <- dt[nPerbin>=minBinsize,]
    
    
   
    dt$rowID =1:length(dt$mz)
    dt$ID <- c(1,diff(dt$ID))
    dt$ID[dt$ID!=0] <- 1
    dt$ID <- cumsum(dt$ID)  
    pm <-  dt[ ,list(n=length(mz),max_nlos=max(nos),max_nlos_id = rowID[nos == max(nos)]), by=ID]
    nPerbin <- nPerbin[nPerbin>=minBinsize]
    critV <- lookup[nPerbin]
    max_nlos_id <- rep(pm$max_nlos_id,pm$n)
    max_nlos <- rep(pm$max_nlos,pm$n)
    cutIdx <- ifelse(max_nlos>critV,max_nlos_id,-1)
    cutpos <- unique(cutIdx[cutIdx>0])
    dt$nos[cutpos] <- -255
    ID2 <- dt$ID
    dt$ID <- c(1,diff(dt$ID))
    dt$ID[cutpos+1] <- 1
    dt$ID <- cumsum(dt$ID)
    if(length(cutpos)==0){bin_mz <- F}
      }
    return(dt)
}


RT_split <- function(dt,alpha){
  ## Function looking for Gaps in RT of bins
  
  dt <- dt[order(dt$ID,dt$Scans),]
  
  l_ID_pre <- length(unique(dt$ID))
  
  diff_sc <- calcNosConst(x = dt$Scans)
  
  
  dt$ID <- c(1,diff(dt$ID))
  
  dt$ID[which(diff_sc>6)+1]  <- 1
  
  
  dt$ID <- cumsum(dt$ID)
  
  
  
  if(l_ID_pre == length(unique(dt$ID))){return(list(dt,F))}
  return(list(dt,T))
  
  
}



size_check <- function(dt,minBinsize){
  nPerbin <-  dt[ ,list(n=length(mz)), by=ID]
  nPerbin  <- rep(nPerbin$n,nPerbin$n)
  
  dt <- dt[nPerbin>=minBinsize,]
  dt$rowID =1:length(dt$mz)
  dt$ID <- c(1,diff(dt$ID))
  dt$ID[dt$ID!=0] <- 1
  dt$ID <- cumsum(dt$ID)
  return(dt)}

nlos_max_func <- function(nlos,ID){
  
  id_raw <- 1:length(ID) 
  nlos_sc = ((0.0+0.95)*(nlos-min(nlos))/(max(na.omit(nlos[is.finite(nlos)]))-min(na.omit(nlos[is.finite(nlos)])))) -0
  nlos_sc_ID = nlos_sc + ID 
  
  
  
  
  if(length(unique(ID))==1){
    id <-which.max(nlos)
    nlos_max <- nlos[id]
    
  }else{
    
    dpp <- cbind(ID,id_raw, nlos_sc,nlos_sc_ID,nlos)
    dpp <- dpp[order(dpp[,4]),]
    
    breaks <- c(which(c(diff(dpp[,1]))==1),length(dpp[,1]))
    
    nlos_max <- dpp[breaks,5]
    id <- dpp[breaks,2]
  }
  
  return(list(nlos_max,id))                   
}  


evalBins <- function(mz,Scans,nos,minBinsize,err_mz,alpha,rt,I,lookup){
  ID <- rep(1,length(mz))
  mean_err_mz <- mean(err_mz)
  nos <- calcNos(mz,mean_err_mz)
  
  dt <- data.table(mz=mz,nos = nos,ID = ID,rawID = 1:length(mz),err_mz = err_mz)
  bin_mz <- c(T)
  while(bin_mz){
    
    pm <-  dt[ ,list(n=length(mz),mean_err_mz = mean(err_mz)), by=ID]
    
    
    nPerbin <- rep(pm$n,pm$n)
    mean_err_mz <- rep(pm$mean_err_mz,pm$n)
    dt$nos <- calcNos(dt$mz,mean_err_mz)
    dt$nos[which(diff(dt$ID)!=0)] <- -255
    dt <- dt[nPerbin>=minBinsize,]
    dt$rowID =1:length(dt$mz)

    dt$ID <- c(1,diff(dt$ID))
    dt$ID[dt$ID!=0] <- 1
    dt$ID <- cumsum(dt$ID)
    pm <-  dt[ ,list(n=length(mz),max_nlos=max(nos),max_nlos_id = rowID[nos == max(nos)],mean_err_mz = mean(err_mz)), by=ID]
    

    nPerbin <- rep(pm$n,pm$n)
    critV <- lookup[nPerbin]
    max_nlos <- pm$max_nlos
    max_nlos <- rep(max_nlos,pm$n)
    max_nlos_id <- pm$max_nlos_id
    max_nlos_id <- rep(max_nlos_id,pm$n)
    cutIdx = ifelse(max_nlos>critV,max_nlos_id,-1)  
    cut_pos <- unique(cutIdx[cutIdx>0])
    dt$nos[cut_pos] <- -255
    ID2 <- dt$ID
    dt$ID <- c(1,diff(dt$ID))
    dt$ID[cut_pos+1] <- 1
    dt$ID <- cumsum(dt$ID)
    if(length(cut_pos)==0){bin_mz <- F}
  }
  dt$Scans <- Scans[dt$rawID]
  dt$err_mz <- err_mz[dt$rawID]
  further_split <- T
  
  while(further_split){
    id_pre <- length(unique(dt$ID))
    
    RT_split_res <- RT_split(dt,alpha)
    dt <- RT_split_res[[1]]
    if(RT_split_res[[2]]==F){break}
    dt <- size_check(dt,minBinsize)
    
    
    dt <- mz_later_split(dt,alpha,minBinsize,lookup)
   
  }
  
  return(list(dt$rawID,dt$ID))
  
}



findBins <- function(mz,err_mz,rt,minBinSize,I,Scans,alpha,lookup){
  
  mean_err_mz <- mean(err_mz)
  nos <- calcNos(mz,mean_err_mz)
  td <- evalBins(mz = mz,nos = nos,minBinsize = minBinSize,Scans = Scans,err_mz = err_mz,alpha = alpha,rt = rt, I = I,lookup)
  
  return(td)
  
  
}




Qscore_binning <- function(mz,ID,Scans){
  ## Function to calculate DQSbin in analogy to the silhouette score
  if(length(unique(ID))==1){return(rep(NA,length(mz)))}
  filter_ID <- ID>0
  
  rt_binl <- split(Scans[filter_ID],f = ID[filter_ID])
  mz_binl <- split(mz[filter_ID],f = ID[filter_ID])
  row_binl <- 1:length(mz)
  row_n_dt <- row_binl*0
  row_binl <- split(row_binl[filter_ID],f = ID[filter_ID])
  len_rowbinl <- as.numeric(lapply(rt_binl,length))
  matrix2l <- lapply(rt_binl,FUN= function(x){matrix(rep(x,2),ncol = 2)})
  mz_mat1l <- lapply(mz_binl, FUN = function(x){matrix(rep(x,2),ncol=2)})
  matrix2vl <- lapply(matrix2l,FUN=function(x){as.numeric(x)})
  checkupl <- lapply(matrix2vl, FUN = function(x){ (1:(length(x)/2))})
  mean_dist <- rep(0,length(mz))
  
  for(bin in 1:length(rt_binl)){
    binOpen <- T
    rt_bin <- rt_binl[[bin]]
    row_bin <- row_binl[[bin]]
    matrix2 <- matrix2l[[bin]]
    matrix2v <- matrix2vl[[bin]]
    mz_bin <- mz_binl[[bin]]
    mz_mat1 <- mz_mat1l[[bin]]
    len_rowbin <- len_rowbinl[bin]
    checkup <- checkupl[[bin]]
    
    k <- 1
    row_next <- c(row_bin[1],row_bin[len_rowbin])
    mat_row <- length(mz)
    
    mean_dist[row_bin] <- fast_mean_distance(mz_bin)
    
    while(binOpen){
      
      row_next <- row_next + c(-1,1)
      row_next[row_next<1] <- 1
      row_next[row_next>mat_row] <- mat_row
      rt_next <- c(Scans[row_next[1]],Scans [row_next[2]])
      
      rt_mat <-  abs(rep(rt_next,each=len_rowbin)-matrix2v)<=6
      
      if(sum(rt_mat[c(checkup,checkup+len_rowbin)]) == 0){
        k <- k+1
      }else{
        
        rt_mat <-  matrix(rt_mat,ncol=2)
        xor_logic <- xor(rt_mat[,1],rt_mat[,2])
        row_neighbor <- (rt_mat*xor_logic)%*%as.matrix(row_next)
        
        nb <- (rt_mat[,1]+rt_mat[,2])==2
        if(sum(nb)>0){
          mz_next <- c(mz[row_next[1]],mz[row_next[2]])
          mz_mat2 <- matrix(data =  rep(mz_next,each=len_rowbin),ncol = 2)
          mz_mat3 <- abs(mz_mat1 - mz_mat2)
          row_neighbor[nb] <- ifelse(mz_mat3[,1]<mz_mat3[,2],row_next[1],row_next[2])[nb]
        }
        
        checkup <- which(row_n_dt[row_bin] ==0)
        
        row_n_dt[row_bin][checkup] <- as.numeric(row_neighbor)[checkup]
        
        
        
        
        if(length(checkup)==0){binOpen <- F}
        k <- k+1
      }
      
      
      
      
    }
    
  }
  
  mz_f <- mz[filter_ID]
  mz_p <- mz[row_n_dt]
  mz_d <- abs(mz_f-mz_p)
  mean_dist_f <- mean_dist[filter_ID]
  A <- 1/(1+mean_dist[filter_ID])
  si <- ((mz_d-mean_dist[filter_ID])/(ifelse(mz_d>mean_dist_f,mz_d,mean_dist_f)))*A
  si <- (si+1)/2
  return(si)
}

fast_mean_distance <- function(x){
  n <- length(x)
  i <- rep(1:n,each = n)
  j <- rep(1:n,n)
  dxn <- abs(x[j]-x[i])
  dxn2 <- cumsum(dxn)
  dxn2 <- c(0,dxn2[seq(from=n,to=length(dxn),by=n)])
  dxn3 <- dxn2[-1]-dxn2[-length(dxn2)]
  dxn3 <- dxn3/(n-1)
  return(dxn3)
}





qBinning <- function(path,alpha,minBinsize){
  #Wrapper Function for import of qCentroids centroided Mass spectra
  xt22 <- data.table::fread(file = path,sep = ",")
  xt22 <- xt22[order(xt22$`RT [s]`),]
  xt22$Scans <- c(1,diff(xt22$`RT [s]`))
  xt22$Scans[xt22$Scans!=0] <- 1
  xt22$Scans <- cumsum(xt22$Scans)
  
  xt22 <- xt22[order(xt22[,1]),]
  xt2 <- xt22[!is.na(xt22$DQS),]
  xt2 <- xt2[!is.na(xt2$`Centroid Error`),]
  xt2$`Peak height` <- as.numeric(xt2$`Peak height`)
  
  xt2$binOpen <- c(TRUE)
  
  
  
  DQS <- xt2$DQS
  mz <- xt2$Centroid
  

  ## Dispersion estimate applied in Order Statistics
  err_mz <- as.numeric(xt2$`Centroid Error`)
  
  rt = xt2$`RT [s]`
  
  I = as.numeric(xt2$`Peak area`)
  H = as.numeric(xt2$`Peak height`)
  Scans = xt2$Scans
  lookup <- critVal(1:length(mz),alpha)
  
  ## Function to find EICs/Bins
  EICs <-  findBins(mz = mz,err_mz = err_mz,rt = rt,minBinSize = minBinsize,I = I,Scans = Scans,alpha = alpha,lookup = lookup)
  
  
  df <- data.frame(mz=mz,rt=rt, Scans = Scans,DQS = DQS,err_mz = err_mz,I = I,Height = H)
  df$ID <- c(-1)
  df$ID[EICs[[1]]] <- EICs[[2]]
  
  df$DQSbin <- c(-1)
  ### Calculate DQSbin
  df$DQSbin[df$ID>0] <- Qscore_binning(mz = df$mz,ID = df$ID,Scans = df$Scans)
  df_export <- data.frame(mz=df$mz,rt=df$rt,intensity=df$I,DQScen=df$DQS,DQSbin=df$DQSbin,ID= df$ID)
  df_export <- df_export[df_export$ID>0,]
  return(df_export)
  
}



EICs <- qBinning(path = "example_path",alpha = 0.01,minBinsize = 5)



