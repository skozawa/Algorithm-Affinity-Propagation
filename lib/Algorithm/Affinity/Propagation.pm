package Algorithm::Affinity::Propagation;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use List::Util qw/max min sum/;
use Math::GSL::Matrix;
use Math::GSL::Vector qw/gsl_vector_max_index/;

sub new {
    my ($class ,%args) = @_;
    bless {
        lambda         => $args{lambda}  || 0.9,
        iterate        => $args{iterate} || 50,
        examplers      => [],
    }, $class;
}

sub run {
    my ($self, $similarity) = @_;
    $self->initialize($similarity);

    for my $i ( 1 .. $self->{iterate} ) {
        $self->update_responsibility;
        $self->update_availability;
    }
    $self->assign_exampler;
}

sub initialize {
    my ($self, $data) = @_;
    my $size = @$data;
    my $similarity = Math::GSL::Matrix->new($size, $size);
    $similarity->set_row($_, $data->[$_]) for (0 .. $size-1);

    $self->{similarity}     = $similarity;
    $self->{responsibility} = Math::GSL::Matrix->new($size, $size);
    $self->{availability}   = Math::GSL::Matrix->new($size, $size);
}

sub update_responsibility {
    my $self = shift;

    my $A_and_S = $self->{availability} + $self->{similarity};
    my ($rows, $cols) = $self->{responsibility}->dim;
    my $max_A_and_S = Math::GSL::Matrix->new($rows, $cols);
    for my $i ( 0 .. $rows - 1 ) {
        my $max_array = $self->_max_array([ $A_and_S->row($i)->as_list ]);
        $max_A_and_S->set_row($i, $max_array);
    }

    $self->{responsibility} = $self->{responsibility} * $self->{lambda} +
        ($self->{similarity} - $max_A_and_S) * (1 - $self->{lambda});
}

# calculate max{a(i, k') + s(i, k')} (k!=k') matrix
sub _max_array {
    my ($self, $array) = @_;
    my $max_value = -1 * 'inf';
    my $second_max_value = -1 * 'inf';
    my $max_index = -1;
    for my $i ( 0 .. $#{$array} ) {
        if ( $max_value <= $array->[$i] ) {
            $second_max_value = $max_value;
            $max_value = $array->[$i];
            $max_index = $i;
        } elsif ( $second_max_value <= $array->[$i] ) {
            $second_max_value = $array->[$i];
        }
    }
    my $max_array = [ map { $max_value } (0..$#{$array}) ];
    $max_array->[$max_index] = $second_max_value;
    return $max_array;
}

sub update_availability {
    my $self = shift;

    my $availability_transpose = $self->{availability}->transpose;
    my ($rows, $cols) = $self->{availability}->dim;
    my $new_availability = Math::GSL::Matrix->new($rows, $cols);
    for my $k ( 0 .. $cols - 1 ) {
        my $res = [ $self->{responsibility}->col($k)->each(sub { max(0, shift) })->as_list ];
        # sum max(0, r(i', k))
        my $sum = sum @$res;
        # min(0, r(k,k) + sum max(0, r(i', k) - r(i, k))
        my $availability_k = [ map { min(0, $_) } map { $self->{responsibility}->get_elem($k, $k) + $sum - $_ } @$res ];
        $availability_k->[$k] = $sum - $res->[$k]; # a(k, k)
        $new_availability->set_row($k, $availability_k);
    }
    $self->{availability} = $self->{availability} * $self->{lambda} +
        $new_availability->transpose * (1 - $self->{lambda});
}

sub assign_exampler {
    my $self = shift;
    my $A_and_R = $self->{responsibility} + $self->{availability};
    for my $i ( 0 .. $A_and_R->rows - 1 ) {
        my $row = $A_and_R->row($i)->as_vector;
        my $max_index = gsl_vector_max_index($row->raw);
        $self->{examplers}->[$i] = $max_index;
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Algorithm::Affinity::Propagation - It's new $module

=head1 SYNOPSIS

    use Algorithm::Affinity::Propagation;

=head1 DESCRIPTION

Algorithm::Affinity::Propagation is ...

=head1 LICENSE

Copyright (C) skozawa.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

skozawa E<lt>skozawa@hatena.ne.jpE<gt>

=cut

