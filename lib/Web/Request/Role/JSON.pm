package Web::Request::Role::JSON;

# ABSTRACT: Make handling JSON easier in Web::Request

our $VERSION = '1.000';

use 5.010;
use Moose::Role;
use JSON::MaybeXS;
use Encode;

sub decoded_json_content {
    my $self = shift;

    # Web::Request->content will decode content based on
    # $req->encoding, which is utf8 for JSON. So $content has UTF8 flag
    # on, which means we have to tell JSON::MaybeXS to turn
    # utf8-handling OFF

    return JSON::MaybeXS->new(utf8=>0)->decode($self->content);

    # Alternatives:
    # - reencode the content (stupid because double the work)
    #   decode_json(encode_utf8($self->content))
    # - set $self->encoding(undef), and set it back after decoding
}

sub new_json_response {
    my ( $self, $data, $header_ref, $status ) = @_;

    $status ||= 200;
    my $headers;
    if ($header_ref) {
        if (ref($header_ref) eq 'ARRAY') {
            $headers = HTTP::Headers->new(@$header_ref);
        }
        elsif (ref($header_ref) eq 'HASH') {
            $headers = HTTP::Headers->new(%$header_ref);
        }
    }
    $headers ||= HTTP::Headers->new;
    $headers->header( 'content-type' => 'application/json' );

    return $self->new_response(
        headers => $headers,
        status  => $status,
        content => decode_utf8( encode_json($data) ),
    );
}

sub new_json_error {
    my ( $self, $message, $status ) = @_;
    $status ||= 400;
    my $body;
    if ( ref($message) ) {
        $body = $message;
    }
    else {
        $body = { status => 'error', message => "$message" };
    }

    return $self->new_response(
        headers => [ content_type => 'application/json' ],
        status  => $status,
        content => decode_utf8( encode_json($body) ),
    );
}

1;

=head1 SYNOPSIS

  # Create a request handler
  package My::App::Request;
  use Moose;
  extends 'Web::Request';
  with 'Web::Request::Role::JSON';

  # Make sure your app uses your request handler, e.g. using OX:
  package My::App::OX;
  sub request_class {'My::App::Request'}

  # Finally, in some controller action
  sub create_POST {
      my ($self, $req) = @_;

      my $data    = $req->decoded_json_content;
      my $created = $self->model->create($data);
      return $self->new_json_response($created, undef, 201);
  }

=head1 DESCRIPTION

C<Web::Request::Role::JSON> provides a few methods that make handling
JSON in L<Web::Request> a bit easier.

Please note that all methods return a L<Web::Response> object.
Depending on the framework you use (or lack thereof), you might have
to call C<finalize> on the response object to turn it into a valid
PSGI response.

=head2 METHODS

=head3 decoded_json_content

  my $perl_hash = $req->decoded_json_content;

Extracts and decodes a JSON payload from the request.

=head3 new_json_response

  $req->new_json_response( $data );
  $req->new_json_response( $data, $header_ref );
  $req->new_json_response( $data, $header_ref, $http_status );

Convert your data to JSON and generate a new response with correct HTTP headers.

You can pass in more headers as the second argument (either hashref or
arrayref). These headers will be passed straight on to
C<< HTTP::Headers->new() >>.

You can also pass a HTTP status code as the third parameter. If none
is provided, we default to C<200>.

=head3 new_json_error

  $req->new_json_response( 'something is wrong' );
  $req->new_json_response( $error_data );
  $req->new_json_response( $error, $status );

Generate a JSON object out of your error message, if the message is a
plain string. But you can also pass in a data structure that will be
converte to JSON.

Per default, HTTP status is set to C<400>, but you can pass any other
status as a second argument. (Yes, there is no checking if you pass a
valid status code or not. You're old enough to not do stupid things..)

=head1 THANKS

Thanks to

=over

=item *

L<validad.com|https://www.validad.com/> for supporting Open Source.

=back

