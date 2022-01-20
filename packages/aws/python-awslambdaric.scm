(define-module (aws python-awslambdaric)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system python)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages python-build))

(define-public python-awslambdaric
  (package
   (name "python-awslambdaric")
   (version "1.2.2")
   (source
    (origin
     (method git-fetch)
     (uri (git-reference
           (url "https://github.com/aws/aws-lambda-python-runtime-interface-client/")
           (commit version)))
     (file-name (git-file-name name version))
     (sha256
      (base32
       "1r4b4w5xhf6p4vs7yx89kighlqim9f96v2ryknmrnmblgr4kg0h1"))))
   (build-system python-build-system)
   (arguments
    `(#:phases
      (modify-phases %standard-phases				 
		     (add-after 'unpack 'extract-deps
		       (lambda* (#:key inputs #:allow-other-keys)
			 ;; The package has two patched dependencies aws-lambda-cpp and curl.
			 ;; The building of the dependencies is triggered from setup.py.
			 ;; With the code below we extract the packages. We patch them to fix
			 ;; the correct shebangs and autoconf scripts and we trigger the build.
			 ;; Another approach is to have dedicated guix packages with all the patches
			 ;; included but it is an additional overhead and the packages are not going
			 ;; to be reused by any other packages so decided to keep them as part of
			 ;; the current phase without polluting the repo with additional patch files.
			 (let ((artifacts (string-append (getcwd) "/deps/artifacts"))
			       (patch (assoc-ref %standard-phases 'patch-generated-file-shebangs))
			       (curl "curl-7.77.0")
                               (aws-lambda-cpp "aws-lambda-cpp-0.2.6"))
                           (substitute* "setup.py"
                             (("check_call\\(") "# check_call("))
                           (mkdir artifacts)
                           (invoke "tar" "xvf" (string-append "deps/" curl ".tar.gz") "-C" "deps/")
                           (invoke "tar" "xvf" (string-append "deps/" aws-lambda-cpp ".tar.gz") "-C" "deps/")
                           (with-directory-excursion "deps"
                             (patch)
                             (with-directory-excursion curl
                               (invoke "./configure"
                                       (string-append "SHELL=" (which "sh"))
                                       (string-append "CONFIG_SHELL=" (which "sh"))
                                       "--prefix" artifacts
                                       "--disable-shared"
                                       "--without-ssl"
                                       "--without-zlib")
                               (invoke "make")
                               (invoke "make" "install")
                               )
                             (with-directory-excursion aws-lambda-cpp
                               (mkdir "build")
                               (chdir "build")
                               (invoke "cmake" ".."
                                       (string-append "-DCMAKE_CXX_FLAGS=" "-fPIC")
                                       (string-append "-DCMAKE_INSTALL_PREFIX=" artifacts)
                                       (string-append "-DENABLE_LTO=" "$ENABLE_LTO")
                                       (string-append "-DCMAKE_MODULE_PATH=" artifacts "/lib/pkgconfig"))
                               (invoke "make")
                               (invoke "make" "install")))
			   #t)))
		     (replace 'check
                       (lambda* (#:key tests? #:allow-other-keys)
                         (when tests?
                           (setenv "PYTHONPATH"
                                   (string-append (getcwd) ":" (getenv "PYTHONPATH")))
                           (invoke "pytest")))))))
   (native-inputs
    `(("coreutils" ,coreutils)
      ("cmake" ,cmake)
      ("perl" ,perl)
      ("python-pytest" ,python-pytest)
      ("python-pytest-cov" ,python-pytest-cov)
      ("python-coverage" ,python-coverage)
      ("python-flake8" ,python-flake8)
      ("python-tox" ,python-tox)
      ("python-pylint" ,python-pylint)
      ("python-black" ,python-black)
      ("python-mock" ,python-mock)
      ("python-importlib-metadata" ,python-importlib-metadata)
      ("patch" ,patch)
      ("autoconf" ,autoconf)
      ("automake" ,automake)
      ("libtool" ,libtool)
      ("binutils-2.33" ,binutils-2.33)
      ("python-wheel" ,python-wheel)))
   (propagated-inputs
    `(("python-simplejson" ,python-simplejson)))
   (home-page "https://github.com/aws/aws-lambda-python-runtime-interface-client/")
   (synopsis "AWS Lambda Python Runtime Interface Client")
   (description "Runtime Interface Clients (RIC), that implement the
                  Lambda Runtime API, allowing you to seamlessly extend your preferred
                  base images to be Lambda compatible. The Lambda Runtime Interface
                  Client is a lightweight interface that allows your runtime to receive
                  requests from and send requests to the Lambda service.")
   (license license:asl2.0)))
