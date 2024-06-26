#' Compiler arguments for using Rhdf5lib
#' 
#' This function returns values for \code{PKG_LIBS} variables for use in 
#' Makevars files.
#' 
#' @param opt A scalar character from the list of available options; 
#' default is \code{PKG_CXX_LIBS}.  Valid options are \code{PKG_C_LIBS},
#' \code{PKG_CXX_LIBS}, \code{PKG_C_HL_LIBS} and \code{PKG_CXX_HL_LIBS}, where
#' \code{HL} indicates that you want to include the HDF5 'high-level' API and
#' \code{CXX} denotes including the C++ interface. 
#' @return \code{NULL}; prints the corresponding value to stdout.
#' @examples
#' pkgconfig("PKG_C_LIBS")
#' pkgconfig("PKG_CXX_LIBS")
#' pkgconfig("PKG_C_HL_LIBS")
#' pkgconfig("PKG_CXX_HL_LIBS")
#' @export
#' @rawNamespace if(tools:::.OStype() == "windows") { importFrom(utils, shortPathName) }
pkgconfig <- function(opt = c("PKG_CXX_LIBS", "PKG_C_LIBS", "PKG_CXX_HL_LIBS", "PKG_C_HL_LIBS")) {
  
  path <- Sys.getenv(
    x = "RHDF5LIB_RPATH",
    unset = system.file("lib", package="Rhdf5lib", mustWork=TRUE)
  )
  
  if (nzchar(.Platform$r_arch)) {
    arch <- sprintf("/%s", .Platform$r_arch)
  } else {
    arch <- ""
  }
  patharch <- paste0(path, arch)

  sysname <- Sys.info()['sysname']
  if(sysname == "Windows") {
    
    ## add "-ucrt" to the library directory if needed
    ## this might be removed in the future - 2021-01-20
    if(!is.null(R.version$crt) && R.version$crt == "ucrt" && R.version$arch == "x86_64") {
      patharch <- paste0(patharch, "-ucrt")
    }
    
    ## for some reason double quotes aren't always sufficient on Windows
    ## so we use the 8+3 form of the path and replace slashes
    patharch <- gsub(x = utils::shortPathName(patharch),
                     pattern = "\\",
                     replacement = "/", 
                     fixed = TRUE)
    
    winlibs <- "-lcurl -lssh2 -lssl -lcrypto -lwldap32 -lws2_32 -lcrypt32 -lszip -lz -lpsapi"
    if(!is.null(R.version$crt) && R.version$crt == "ucrt") {
      winlibs <- gsub(pattern = "-lszip", replacement = "-lsz -laec", x = winlibs, fixed = TRUE)
    }
  }
  
  result <- switch(match.arg(opt), 
                   PKG_C_LIBS = {
                     switch(sysname, 
                            Windows = {
                              sprintf('-L%s -lhdf5 %s', 
                                      patharch, winlibs)
                            }, {
                              sprintf('"%s/libhdf5.a"%s%s', 
                                      patharch, .getSzipLoc(patharch), .getDynamicLinks())
                            }
                     )
                   }, 
                   PKG_CXX_LIBS = {
                     switch(sysname, 
                            Windows = {
                              sprintf('-L%s -lhdf5_cpp -lhdf5 %s', 
                                      patharch, winlibs)
                            }, {
                              sprintf('"%s/libhdf5_cpp.a" "%s/libhdf5.a"%s%s',
                                      patharch, patharch, .getSzipLoc(patharch), .getDynamicLinks())
                            }
                     )
                   },
                   PKG_C_HL_LIBS = {
                     switch(sysname, 
                            Windows = {
                              sprintf('-L%s -lhdf5_hl -lhdf5 %s', 
                                      patharch, winlibs)
                            }, {
                              sprintf('"%s/libhdf5_hl.a" "%s/libhdf5.a"%s%s', 
                                      patharch, patharch, .getSzipLoc(patharch), .getDynamicLinks())
                            }
                     )
                   }, 
                   PKG_CXX_HL_LIBS = {
                     switch(sysname, 
                            Windows = {
                              sprintf('-L%s -lhdf5_hl_cpp -lhdf5_hl -lhdf5_cpp -lhdf5 %s', 
                                      patharch, winlibs)
                            }, {
                              sprintf('"%s/libhdf5_hl_cpp.a" "%s/libhdf5_hl.a" "%s/libhdf5_cpp.a" "%s/libhdf5.a"%s%s',
                                      patharch, patharch, patharch, patharch, .getSzipLoc(patharch), .getDynamicLinks())
                            }
                     )
                   }
  )
  
  cat(result)
}

#' Report the version of HDF5 distributed with this package
#' 
#' This function returns the version number of the HDF5 library that is 
#' distributed with this package.
#' 
#' @return Returns a \code{character} vector of length 1 containing the version
#' number.
#' 
#' @examples
#' getHdf5Version()
#' @export
getHdf5Version <- function() {
  cReturn <- .Call("Rhdf5lib_hdf5_libversion", 
        PACKAGE = "Rhdf5lib")
  versionNum <- paste(cReturn, collapse = ".")
  return(versionNum)
}

#' Return the link flags determined when HDF5 was configured
#' 
#' @keywords internal
.getDynamicLinks <- function() {
  sysname <- Sys.info()['sysname']
  if(sysname == "Windows") {
    links <- "-lz"
  } else {
    settings_file <- system.file('include', 'libhdf5.settings', package = "Rhdf5lib", mustWork = TRUE)
    libhdf5_settings <- readLines(settings_file)
    line <- grep("Extra libraries", x = libhdf5_settings)
    links <- strsplit(libhdf5_settings[line], split = ":")[[1]][2]
  }
  return(links)
}

#' If we compiled our own version of SZIP this returns the link path
#' Otherwise it returns an empty string.
#' 
#' @keywords internal
.getSzipLoc <- function(path) {
  
  status <- file.exists(file.path(path, "libsz.a"))
  if(isTRUE(status)) {
    ldflags <- sprintf(' -L"%s"', path)
  } else {
    ldflags <- ""
  }
  return(ldflags)
}