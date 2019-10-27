use utf8;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Slurp qw(write_file read_file);
use File::Spec;
use JSON::XS qw(encode_json decode_json);
use OAuth::Lite::Consumer;
use Plack::Builder;
use Plack::Middleware::Session;
use Plack::Response;
use Plack::Session;
use Router::Boom;

my $consumer_file = File::Spec->catdir(dirname(__FILE__), 'var', 'consumer.json');
my $consumer_json = read_file($consumer_file);
my $consumer_data = decode_json($consumer_json);
my $consumer = OAuth::Lite::Consumer->new(
    consumer_key       => $consumer_data->{consumer_key},
    consumer_secret    => $consumer_data->{consumer_secret},
    site               => 'https://api.zaim.net',
    request_token_path => '/v2/auth/request',
    access_token_path  => '/v2/auth/access',
    authorize_path     => 'https://auth.zaim.net/users/auth',
);

my $router = Router::Boom->new;
$router->add('/', sub {
    my ($req, $session) = @_;
    my $message = $session->remove('message') || 'hello';
    my $res = Plack::Response->new(200);
    $res->body($message);
    return $res->finalize;
});

$router->add('/auth', sub {
    my ($req, $session) = @_;
    my $request_token = $consumer->get_request_token(
        callback_url => 'https://zaim.tetsu.io/callback',
    );
    $session->set(request_token => $request_token);
    my $url = $consumer->url_to_authorize(
        token => $request_token,
    );
    my $res = Plack::Response->new;
    $res->redirect($url);
    return $res->finalize;
});

$router->add('/callback', sub {
    my ($req, $session) = @_;
    my $params = $req->parameters->as_hashref;
    my $verifier = $params->{oauth_verifier};
    my $request_token = $session->get('request_token');
    my $access_token = $consumer->get_access_token(
        token    => $request_token,
        verifier => $verifier,
    );
    $session->remove('request_token');
    $session->set(access_token => $access_token);
    my $data = {
        token  => $access_token->token,
        secret => $access_token->secret,
    };
    my $token_file = File::Spec->catdir(dirname(__FILE__), 'var', 'access_token.json');
    write_file($token_file, encode_json($data));

    $session->set('message', 'authentication complete');
    my $res = Plack::Response->new(200);
    $res->redirect('/');
    return $res->finalize;
});

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $session = Plack::Session->new($env);
    my ($code) = $router->match($env->{PATH_INFO});
    return ['404', ['Content-Type' => 'text/plain'], ['Not Found.']] unless $code;
    return $code->($req, $session);
};

builder {
    enable "Session";
    $app;
}

__END__
