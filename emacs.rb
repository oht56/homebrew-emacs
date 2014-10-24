require "formula"

class Emacs < Formula
  homepage "https://www.gnu.org/software/emacs/"
  url "http://ftpmirror.gnu.org/emacs/emacs-24.4.tar.xz"
  mirror "https://ftp.gnu.org/pub/gnu/emacs/emacs-24.4.tar.xz"
  sha256 "47e391170db4ca0a3c724530c7050655f6d573a711956b4cd84693c194a9d4fd"

  bottle do
    revision 1
    sha1 "921a8a802cb99821d8cc6a1a73ad99bafb09dd77" => :yosemite
    sha1 "9d076a90ed7ce5b70fe89a7400ff95b8d7089132" => :mavericks
    sha1 "74439e42f3147b814b4fa451524789d388e24ed8" => :mountain_lion
  end

  option "cocoa", "Build a Cocoa version of emacs"
  option "with-x", "Include X11 support"
  option "use-git-head", "Use Savannah (faster) git mirror for HEAD builds"
  option "keep-ctags", "Don't remove the ctags executable that emacs provides"
  option "japanese", "Patch for Japanese input methods"

  head do
    if build.include? "use-git-head"
      url "http://git.sv.gnu.org/r/emacs.git"
    else
      url "bzr://http://bzr.savannah.gnu.org/r/emacs/trunk"
    end

    depends_on "autoconf" => :build
    depends_on "automake" => :build
  end

  if build.include? "cocoa"
     depends_on "autoconf" => :build
     depends_on "automake" => :build
  end if

  patch :p1 do #inline-patch by GO
    url "http://plamo.linet.gr.jp/~matsuki/mac/emacs-24.4-20140417-inline.patch"
    sha1 "90456a6856c1e3a11ca10a73866ee1aea371aad4"
  end if build.include? "cocoa" and build.include? "japanese"

  depends_on "pkg-config" => :build
  depends_on :x11 if build.with? "x"
  depends_on "d-bus" => :optional
  depends_on "gnutls" => :optional
  depends_on "librsvg" => :optional
  depends_on "imagemagick" => :optional
  depends_on "mailutils" => :optional
  depends_on "glib" => :optional

  fails_with :llvm do
    build 2334
    cause "Duplicate symbol errors while linking."
  end

  def install
    # HEAD builds blow up when built in parallel as of April 20 2012
    # FIXME is this still necessary? It's been more than two years, surely any
    # race conditions would have made it into release by now.
    ENV.deparallelize unless build.stable?

    args = ["--prefix=#{prefix}",
            "--enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp",
            "--infodir=#{info}/emacs"]
    args << "--with-file-notification=gfile" if build.with? "glib"
    if build.with? "d-bus"
      args << "--with-dbus"
    else
      args << "--without-dbus"
    end
    if build.with? "gnutls"
      args << "--with-gnutls"
    else
      args << "--without-gnutls"
    end
    args << "--with-rsvg" if build.with? "librsvg"
    args << "--with-imagemagick" if build.with? "imagemagick"
    args << "--without-popmail" if build.with? "mailutils"

    system "./autogen.sh" unless build.stable?

    if build.include? "cocoa"
      args << "--with-ns" << "--disable-ns-self-contained"
      system "./configure", *args
      system "make"
      system "make", "install"
      prefix.install "nextstep/Emacs.app"

      # Replace the symlink with one that avoids starting Cocoa.
      (bin/"emacs").unlink # Kill the existing symlink
      (bin/"emacs").write <<-EOS.undent
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs -nw  "$@"
      EOS
    else
      if build.with? "x"
        # These libs are not specified in xft's .pc. See:
        # https://trac.macports.org/browser/trunk/dports/editors/emacs/Portfile#L74
        # https://github.com/Homebrew/homebrew/issues/8156
        ENV.append "LDFLAGS", "-lfreetype -lfontconfig"
        args << "--with-x"
        args << "--with-gif=no" << "--with-tiff=no" << "--with-jpeg=no"
      else
        args << "--without-x"
      end

      system "./configure", *args
      system "make"
      system "make", "install"
    end

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    unless build.include? "keep-ctags"
      (bin/"ctags").unlink
      (man1/"ctags.1.gz").unlink
    end
  end

  def caveats
    if build.include? "cocoa" then <<-EOS.undent
      A command line wrapper for the cocoa app was installed to:
        #{bin}/emacs
      EOS
    end
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/emacs</string>
        <string>--daemon</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
