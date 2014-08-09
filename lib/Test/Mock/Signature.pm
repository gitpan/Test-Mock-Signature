package Test::Mock::Signature;

use strict;
use warnings;

use Class::Load qw(load_class);

use Test::Mock::Signature::Meta;

our $VERSION = '0.02';
our @EXPORT_OK = qw(any);

sub any() {
    return $Data::PatternCompare::any;
}

sub init { }

sub new {
    my $class  = shift;
    my $singleton = do {
        no strict 'refs';
        ${$class .'::singleton'}
    };
    return $singleton if $singleton;

    my $params = {
        _real_class => do {
            no strict 'refs';
            ${$class .'::CLASS'}
        },
        _method_dispatcher => {},
        @_
    };

    $singleton = bless($params, $class);
    {
        no strict 'refs';
        ${$class .'::singleton'} = $singleton;
    }
    $singleton->init;

    return $singleton;
}

sub method {
    my $self   = shift;
    my $method = shift;
    my $params = [ @_ ];

    return Test::Mock::Signature::Meta->new(
        class  => $self->{'_real_class'},
        method => $method,
        params => $params
    );
}

sub clear {
    my $self   = shift;
    my $method = shift;
    my $params = [ @_ ];
    my $md     = $self->{'_method_dispatcher'};

    unless (scalar @$params) {
        delete $self->{'_method_dispatcher'}->{$method};
        # do not return dispatcher object for GC
        return;
    }

    my $meta = Test::Mock::Signature::Meta->new(
        class  => $self->{'_real_class'},
        method => $method,
        params => $params
    );

    $md->{$method}->delete($meta);
}

sub dispatcher {
    my $self   = shift;
    my $method = shift;
    my $md     = $self->{'_method_dispatcher'};

    return $md->{$method} if exists $md->{$method};

    $md->{$method} = Test::Mock::Signature::Dispatcher->new($self->{'_real_class'} .'::'. $method);
}

sub import {
    my $class = shift;
    my $mock  = do {
        no strict 'refs';
        ${$class . '::CLASS'};
    };

    load_class($mock);

    my $caller = caller;
    my %export = map { $_ => 1 } @EXPORT_OK;

    no strict 'refs';
    no warnings 'redefine';

    *{$mock .'::_tms_mock_instance'} = sub {
        return $class->new;
    };

    for my $i ( @_ ) {
        next unless exists $export{$i};

        my $src_glob = __PACKAGE__  .'::'. $i;
        my $dst_glob = $caller .'::'. $i;

        *$dst_glob = *$src_glob;
    }
}

42;

__END__

=head1 NAME

Test::Mock::Signature - base class for mock modules.

=head1 SYNOPSIS

Create module for mocking CGI:

    package Your::Mock::Module;

    use strict;
    use warnings;

    require Test::Mock::Signature;
    our @ISA = qw(Test::Mock::Signature);

    our $CLASS = 'CGI';

    sub init {
        my $mock = shift;

        $mock->method('new')->callback(
            sub {
                my $class = shift;

                return bless({}, $class);
            }
        );
    }

Use it in tests:

    use Test::More plan => 1;
    use Your::Mock::Module qw( any );
    use CGI;

    my $mock = Your::Mock::Module->new;
    $mock->method('param' => any)->callback( sub { 42 } );

    my $request = CGI->new;

    ok($request->param('something'), 42, 'mocked');

=head1 DESCRIPTION

This module is a base class for your mock module with ability to set callbacks
for defined signature of your method.

=head1 METHODS

=head2 import( any )

This method imports magic constant C<any> from class L<Data::PatternCompare>
and does some magic behind the scene. Also it takes real class name from your
C<our $CLASS> variable.

=head2 new()

Default constructor. To simplify inheritance there are another method defined
C<init()> which will be called from constructor.

=head2 init()

Empty method invoked from constructor C<new()>. Can be overrided to define
default mocked methods e.g.: constructors.

=head2 method($method_name, [ @params ]) : L<Test::Mock::Signature::Meta>

This method does the actual mocking of methods e.g.:

    my $mock = Your::Mock::Module->new;
    my $cgi  = new CGI;

    $mock->method(param => 'get_param')->callback(
        sub {
            return 42;
        }
    );
    print $cgi->param('get_param'); # 42
    print $cgi->param('ANYTHING_ELSE'); # will give original CGI::param behavior

C<@params> can contain object C<any> exported by the mock module if needed for detailed reference please look to: L<Data::PatternCompare>.

Returns object of L<Test::Mock::Signature::Meta> class.

=head2 clear($method_name, [ @params ])

Clear mocking behavior from method. Takes C<$method_name> as a first parameter.
Prototype is optional. If you put only method name it remove all mocks from
this method. If you put prototype parameters it finds this signature and delete
it. e.g.:

    $mock->clear(param => 'get_param'); # delete exact signature
    $mock->clear('param'); # delete all mocked signatures from method "param"

=head2 dispatcher($method_name) : L<Test::Mock::Signature::Dispatcher>

This method returns dispatcher object for the given C<$method_name>. Currently
it's exposed as public just in case. Used for internal use and don't have any
real user examples.

=head1 AUTHOR

cono E<lt>cono@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2014 - cono

=head1 LICENSE

Artistic v2.0

=head1 SEE ALSO

L<Data::PatternCompare>
