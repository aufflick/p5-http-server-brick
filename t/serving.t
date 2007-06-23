use Test::More tests => 8;

BEGIN {
    use_ok( 'HTTP::Server::Brick' );
}

use LWP;
use LWP::UserAgent;
use HTTP::Status;
use POSIX ":sys_wait_h";

my $port = $ENV{HSB_TEST_PORT} || 85432;
my $host = $ENV{HSB_TEST_HOST} || 'localhost';

diag( '' );
diag( "Using port: $port and host: $host");
diag( 'if these are not suitable settings on your machine, set the environment' );
diag( 'variables HSB_TEST_PORT and HSB_TEST_HOST to something suitable.');
diag( '' );

my $server;
ok( $server = HTTP::Server::Brick->new( port => $port, host => $host ), 'Created server object.');
isa_ok( $server, 'HTTP::Server::Brick');

# need to fork off a child to run the server

my $child_pid;
if (!($child_pid = fork())) {
    # child - this will be the server

    diag('Starting server');
    $server->start;
    exit(0);
}

test_url(GET => "/url_that_doesn't_exist", RC_NOT_FOUND, qr/Not Found in Site Map/ );


sub test_url {
    my ($method, $uri, $code, $regex) = @_;

    my $url = "http://$host:$port/$uri";

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(GET => $url);

    my $res;
    ok($res = $ua->request($req), 'LWP Request worked for ' . $url);
    cmp_ok($res->code, '==', $code, "Result code as expected ($code).");
    like($res->content, $regex, "Content matched.");

}

cmp_ok(kill( SIGHUP, $child_pid), '==', 1, "Requesting server shutdown via HUP ($child_pid)");
sleep(6);
waitpid($child_pid, WNOHANG);
cmp_ok(kill( SIGKILL, $child_pid), '==', 0, "Shouldn't need to force kill server");
