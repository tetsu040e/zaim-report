use utf8;
use strict;
use warnings;

use Encode qw(decode_utf8);
use File::Basename qw(dirname);
use File::Slurp qw(read_file);
use File::Spec;
use HTTP::Request::Common;
use JSON::XS qw(decode_json);
use LWP::UserAgent;
use OAuth::Lite::Consumer;
use OAuth::Lite::Token;
use Time::Piece;
use Time::Seconds;

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

my $token_file = File::Spec->catdir(dirname(__FILE__), 'var', 'access_token.json');
my $token_json = read_file($token_file);
my $token_data = decode_json($token_json);
my $access_token = OAuth::Lite::Token->new(%$token_data);

sub main {
    my ($dryrun) = @_;

    my $now = localtime;
    my $start_date = $now - ONE_DAY * 7;
    my $end_date   = $now - ONE_DAY;

    my $map = &get_category_map();
    my $money = &get_money($start_date, $end_date);

    foreach my $m (@$money) {
        next unless $m->{category_id};
        next unless $m->{mode} eq 'payment';
        $map->{$m->{category_id}}->{summary} += $m->{amount};
    }
    my @records = ();
    foreach my $key (%$map) {
        my $data = $map->{$key};
        next unless $data->{summary};
        push @records, $data;
    }
    @records = sort { $b->{summary} <=> $a->{summary} } @records;

    my $message = &generate_message($start_date, $end_date, @records);
    if ($dryrun) {
        warn $message;
    } else {
        &notify($message);
    }
}

sub get_category_map {
    my $res = $consumer->request(
        method => 'GET',
        url    => 'https://api.zaim.net/v2/home/category',
        token  => $access_token,
        params => {},
    );
    my $resource = $res->decoded_content || $res->content;
    my $data = decode_json($resource);
    my $categories = $data->{categories};
    my $map = {};
    foreach my $category (@$categories) {
        next unless $category->{mode} eq 'payment';
        $map->{$category->{id}} = {
            name => $category->{name},
            summary => 0,
        };
    }
    return $map;
}

sub get_money {
    my ($start_date, $end_date) = @_;
    my $res = $consumer->request(
        method => 'GET',
        url    => 'https://api.zaim.net/v2/home/money',
        token  => $access_token,
        params => {
            start_date => $start_date->ymd('-'),
            end_date   => $end_date->ymd('-'),
        },
    );
    unless ($res->is_success) {
        use Data::Printer;
        warn p $res;
        warn(sprintf("zaim api リクエスト失敗\n"));
    }

    my $resource = $res->decoded_content || $res->content;
    my $data = decode_json($resource);
    return $data->{money};
}

sub generate_message {
    my ($start_date, $end_date, @records) = @_;
    my @texts = ();
    foreach my $record (@records) {
        my $summary = $record->{summary};
        1 while $summary =~ s/^(-?\d+)(\d\d\d)/$1,$2/;
        my @names = $record->{name} =~ m/\P{InBasicLatin}/g;
        my $space = '　';
        push @texts, sprintf(
            '%s%s: %7s円',
            $record->{name},
            $space x (6 - scalar(@names)),
            $summary,
        );
    }
    my $text = sprintf(
        "\n\n%s 〜 %s\n\n",
        decode_utf8($start_date->strftime('%m/%d(%a)')),
        decode_utf8($end_date->strftime('%m/%d(%a)')),
    );
    $text .= join("\n", @texts);
    return $text;
}

my $line_token_file = File::Spec->catdir(dirname(__FILE__), 'var', 'line_notify.json');
my $line_token_json = read_file($line_token_file);
my $line_token_data = decode_json($line_token_json);
sub notify {
    my ($message) = @_;
    my $ua = LWP::UserAgent->new;
    my $req = POST(
        'https://notify-api.line.me/api/notify',
        Authorization => sprintf('Bearer %s', $line_token_data->{token}),
        Content => {
            message => $message,
        },
    );
    my $res = $ua->request($req);
    use Data::Printer;
    warn p $res;
}

main(@ARGV);

1;
__END__
