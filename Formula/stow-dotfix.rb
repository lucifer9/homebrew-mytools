class StowDotfix < Formula
  desc "Original GNU Stow with AitorATuin's patches for --dotfiles"
  homepage "https://www.gnu.org/software/stow/"
  url "https://ftp.gnu.org/gnu/stow/stow-2.3.1.tar.gz"
  mirror "https://ftpmirror.gnu.org/stow/stow-2.3.1.tar.gz"
  sha256 "09d5d99671b78537fd9b2c0b39a5e9761a7a0e979f6fdb7eabfa58ee45f03d4b"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://github.com/lucifer9/homebrew-mytools/releases/download/stow-dotfix-2.3.1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, monterey:     "b8ce38d32dc6fbb3ca67142335531c70b665d246fe3fea4e5309b683b22578cb"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "e3b337e760013d13eca9e9fed464cd96a3b1e59e6e94f17ee03ec60c4229a8a3"
  end

  conflicts_with "stow", because: "both install `stow` binaries"

  patch :DATA

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test").mkpath
    system "#{bin}/stow", "-nvS", "test"
  end
end

__END__
diff --git a/lib/Stow.pm.in b/lib/Stow.pm.in
index 77f67b3..87a25e1 100755
--- a/lib/Stow.pm.in
+++ b/lib/Stow.pm.in
@@ -284,6 +284,7 @@ sub plan_unstow {
                     $self->{stow_path},
                     $package,
                     '.',
+		    $path,
                 );
             }
             debug(2, "Planning unstow of package $package... done");
@@ -316,6 +317,7 @@ sub plan_stow {
                 $package,
                 '.',
                 $path, # source from target
+		0,
             );
             debug(2, "Planning stow of package $package... done");
             $self->{action_count}++;
@@ -367,10 +369,12 @@ sub within_target_do {
 #============================================================================
 sub stow_contents {
     my $self = shift;
-    my ($stow_path, $package, $target, $source) = @_;
-
-    my $path = join_paths($stow_path, $package, $target);
+    my ($stow_path, $package, $target, $source, $level) = @_;
 
+    # Remove leading $level times .. from $source
+    my $n = 0;
+    my $path = join '/', map { (++$n <= $level) ? ( ) : $_ } (split m{/+}, $source);
+    
     return if $self->should_skip_target_which_is_stow_dir($target);
 
     my $cwd = getcwd();
@@ -407,6 +411,7 @@ sub stow_contents {
             $package,
             $node_target,                 # target
             join_paths($source, $node),   # source
+	    $level
         );
     }
 }
@@ -429,7 +434,7 @@ sub stow_contents {
 #============================================================================
 sub stow_node {
     my $self = shift;
-    my ($stow_path, $package, $target, $source) = @_;
+    my ($stow_path, $package, $target, $source, $level) = @_;
 
     my $path = join_paths($stow_path, $package, $target);
 
@@ -499,12 +504,14 @@ sub stow_node {
                     $existing_package,
                     $target,
                     join_paths('..', $existing_source),
+		    $level + 1,
                 );
                 $self->stow_contents(
                     $self->{stow_path},
                     $package,
                     $target,
                     join_paths('..', $source),
+		    $level + 1,
                 );
             }
             else {
@@ -531,6 +538,7 @@ sub stow_node {
                 $package,
                 $target,
                 join_paths('..', $source),
+		$level + 1,
             );
         }
         else {
@@ -554,6 +562,7 @@ sub stow_node {
             $package,
             $target,
             join_paths('..', $source),
+	    $level + 1,
         );
     }
     else {
@@ -740,9 +749,7 @@ sub unstow_node_orig {
 #============================================================================
 sub unstow_contents {
     my $self = shift;
-    my ($stow_path, $package, $target) = @_;
-
-    my $path = join_paths($stow_path, $package, $target);
+    my ($stow_path, $package, $target, $path) = @_;
 
     return if $self->should_skip_target_which_is_stow_dir($target);
 
@@ -778,7 +785,7 @@ sub unstow_contents {
             $node_target = $adj_node_target;
         }
 
-        $self->unstow_node($stow_path, $package, $node_target);
+        $self->unstow_node($stow_path, $package, $node_target, join_paths($path, $node));
     }
     if (-d $target) {
         $self->cleanup_invalid_links($target);
@@ -798,7 +805,7 @@ sub unstow_contents {
 #============================================================================
 sub unstow_node {
     my $self = shift;
-    my ($stow_path, $package, $target) = @_;
+    my ($stow_path, $package, $target, $source) = @_;
 
     my $path = join_paths($stow_path, $package, $target);
 
@@ -872,7 +879,7 @@ sub unstow_node {
     elsif (-e $target) {
         debug(4, "  Evaluate existing node: $target");
         if (-d $target) {
-            $self->unstow_contents($stow_path, $package, $target);
+            $self->unstow_contents($stow_path, $package, $target, $source);
 
             # This action may have made the parent directory foldable
             if (my $parent = $self->foldable($target)) {
diff --git a/t/dotfiles.t b/t/dotfiles.t
index a4a45c8..9e70ad4 100755
--- a/t/dotfiles.t
+++ b/t/dotfiles.t
@@ -24,7 +24,7 @@ use warnings;
 
 use testutil;
 
-use Test::More tests => 6;
+use Test::More tests => 10;
 use English qw(-no_match_vars);
 
 use testutil;
@@ -86,6 +86,64 @@ is(
     => 'processed dotfile folder'
 );
 
+#
+# process folder marked with 'dot' prefix
+# when directory exists is target
+#
+
+$stow = new_Stow(dir => '../stow', dotfiles => 1);
+
+make_path('../stow/dotfiles/dot-emacs.d');
+make_file('../stow/dotfiles/dot-emacs.d/init.el');
+make_path('.emacs.d');
+
+$stow->plan_stow('dotfiles');
+$stow->process_tasks();
+is(
+    readlink('.emacs.d/init.el'),
+    '../../stow/dotfiles/dot-emacs.d/init.el',
+    => 'processed dotfile folder when folder exists (1 level)'
+);
+
+#
+# process folder marked with 'dot' prefix
+# when directory exists is target (2 levels)
+#
+
+$stow = new_Stow(dir => '../stow', dotfiles => 1);
+
+make_path('../stow/dotfiles/dot-emacs.d/dot-emacs.d');
+make_file('../stow/dotfiles/dot-emacs.d/dot-emacs.d/init.el');
+make_path('.emacs.d');
+
+$stow->plan_stow('dotfiles');
+$stow->process_tasks();
+is(
+    readlink('.emacs.d/.emacs.d'),
+    '../../stow/dotfiles/dot-emacs.d/dot-emacs.d',
+    => 'processed dotfile folder exists (2 levels)'
+);
+
+#
+# process folder marked with 'dot' prefix
+# when directory exists is target
+#
+
+$stow = new_Stow(dir => '../stow', dotfiles => 1);
+
+make_path('../stow/dotfiles/dot-one/dot-two');
+make_file('../stow/dotfiles/dot-one/dot-two/three');
+make_path('.one/.two');
+
+$stow->plan_stow('dotfiles');
+$stow->process_tasks();
+is(
+    readlink('./.one/.two/three'),
+    '../../../stow/dotfiles/dot-one/dot-two/three',
+    => 'processed dotfile 2 folder exists (2 levels)'
+);
+
+
 #
 # corner case: paths that have a part in them that's just "$DOT_PREFIX" or
 # "$DOT_PREFIX." should not have that part expanded.
@@ -129,3 +187,25 @@ ok(
     -f '../stow/dotfiles/dot-bar' && ! -e '.bar'
     => 'unstow a simple dotfile'
 );
+
+#
+# unstow process folder marked with 'dot' prefix
+# when directory exists is target
+#
+
+$stow = new_Stow(dir => '../stow', dotfiles => 1);
+
+make_path('../stow/dotfiles/dot-emacs.d');
+make_file('../stow/dotfiles/dot-emacs.d/init.el');
+make_path('.emacs.d');
+make_link('.emacs.d/init.el', '../../stow/dotfiles/dot-emacs.d/init.el');
+
+$stow->plan_unstow('dotfiles');
+$stow->process_tasks();
+ok(
+    $stow->get_conflict_count == 0 &&
+    -f '../stow/dotfiles/dot-emacs.d/init.el' &&
+    ! -e '.emacs.d/init.el' &&
+    -d '.emacs.d/'
+    => 'unstow dotfile folder when folder already exists'
+);
