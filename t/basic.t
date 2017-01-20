use strict;
use warnings;
use Test::More;
use HTTP::Request;
use HTTP::Request::Common;
use Plack::Test;
use Plack::Builder;
use Web::Request;
use Encode;
use JSON::MaybeXS;
use utf8;

# Generate a temp request class based on Web::Request and W:R:Role::JSON
my $req_class = Moose::Meta::Class->create(
    'MyReq',
    superclasses => ['Web::Request'],
    roles        => ['Web::Request::Role::JSON'],
    methods      => {
        default_encoding => sub {'UTF-8'}
    }
);

# The fake app we use for testing
my $handler = builder {
    sub {
        my $env  = shift;
        my $req  = $req_class->name->new_from_env($env);
        my $path = $env->{PATH_INFO};

        my $res;

        # decoded_json_content
        if ( $path eq '/post' ) {
            my $data = $req->decoded_json_content;
            return [
                200,
                [ 'Content-Type' => 'text/plain' ],
                [ encode_utf8( $data->{value} ) ]
            ];
        }

        # new_json_response
        elsif ( $path eq '/get/plain' ) {
            $res = $req->new_json_response( { value => 'plain' } );
        }
        elsif ( $path eq '/get/utf8' ) {
            $res = $req->new_json_response( { value => 'töst' } );
        }
        elsif ( $path eq '/get/header' ) {
            $res = $req->new_json_response( { value => 'töst' },
                { 'X-Test' => 42 } );
        }
        elsif ( $path eq '/get/201' ) {
            $res =
                $req->new_json_response( { value => 'created' }, undef, 201 );
        }

        # new_json_error
        elsif ( $path eq '/error/string' ) {
            $res = $req->new_json_error("crash");
        }
        elsif ( $path eq '/error/hash' ) {
            $res =
                $req->new_json_error( { is_error => 1, message => "crash" } );
        }
        elsif ( $path eq '/error/406' ) {
            $res = $req->new_json_error( "flabbergasted", 406 );
        }

        return $res->finalize;
    };
};

# and finally the tests!
test_psgi(
    app    => $handler,
    client => sub {
        my $cb = shift;

        subtest 'decoded_json_content' => sub {
            my $req = HTTP::Request->new(
                POST => 'http://localhost/post',
                [ 'Content-Type' => 'application/json' ], '{"value":42}'
            );
            my $res = $cb->($req);
            is( $res->content, '42', 'content' );
        };

        subtest 'decoded_json_content utf8' => sub {
            my $req1 = HTTP::Request->new(
                POST => 'http://localhost/post',
                [ 'Content-Type' => 'application/json' ],
                encode_json( { value => 'töst' } )
            );
            my $res1 = $cb->($req1);
            is( decode_utf8( $res1->content ),
                'töst', 'decoded json encode_utf8' );

            my $req2 = HTTP::Request->new(
                POST => 'http://localhost/post',
                [ 'Content-Type' => 'application/json' ],
                encode_utf8('{"value":"töst"}')
            );
            my $res2 = $cb->($req2);
            is( decode_utf8( $res2->content ),
                'töst', 'decoded json literal utf8' );
        };

        subtest 'new_json_response plain' => sub {
            my $res = $cb->( GET "http://localhost/get/plain" );
            is( $res->code, 200, 'status' );
            is( $res->content_type, 'application/json', 'content-type' );
            is( decode_utf8( $res->content ), '{"value":"plain"}',
                'content' );
        };

        subtest 'new_json_response utf8' => sub {
            my $res = $cb->( GET "http://localhost/get/utf8" );
            is( $res->code, 200, 'status' );
            is( $res->content_type, 'application/json', 'content-type' );
            is( decode_utf8( $res->content ), '{"value":"töst"}',
                'content' );
        };

        subtest 'new_json_response header' => sub {
            my $res = $cb->( GET "http://localhost/get/header" );
            is( $res->code,             200,                'status' );
            is( $res->content_type,     'application/json', 'content-type' );
            is( $res->header('x-test'), 42,                 'extra header' );
        };

        subtest 'new_json_response 201' => sub {
            my $res = $cb->( GET "http://localhost/get/201" );
            is( $res->code, 201, 'status 201' );
            is( decode_utf8( $res->content ),
                '{"value":"created"}', 'content' );
        };

        subtest 'new_json_error string' => sub {
            my $res = $cb->( GET "http://localhost/error/string" );
            is( $res->code, 400, 'status 400' );
            is( $res->content_type, 'application/json', 'content-type' );
            my $data = decode_json( decode_utf8( $res->content ) );
            is( $data->{status},  'error', 'content.status' );
            is( $data->{message}, 'crash', 'content.message' );
        };
        subtest 'new_json_error hash' => sub {
            my $res = $cb->( GET "http://localhost/error/hash" );
            is( $res->code, 400, 'status 400' );
            is( $res->content_type, 'application/json', 'content-type' );
            my $data = decode_json( decode_utf8( $res->content ) );
            is( $data->{is_error}, 1,       'content.is_error' );
            is( $data->{message},  'crash', 'content.message' );
        };
        subtest 'new_json_error 406' => sub {
            my $res = $cb->( GET "http://localhost/error/406" );
            is( $res->code, 406, 'status 406' );
            is( $res->content_type, 'application/json', 'content-type' );
            my $data = decode_json( decode_utf8( $res->content ) );
            is( $data->{status},  'error',         'content.status' );
            is( $data->{message}, 'flabbergasted', 'content.message' );
        };
    }
);

done_testing;
