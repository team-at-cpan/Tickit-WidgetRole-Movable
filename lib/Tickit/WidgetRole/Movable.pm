package Tickit::WidgetRole::Movable;
# ABSTRACT: 
use strict;
use warnings;
use parent qw(Tickit::Widget);

our $VERSION = '0.001';

=head1 NAME

Tickit::WidgetRole::Movable -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use constant {
	# Resizing horizontally and/or vertically
	NORTH => 1,
	EAST  => 2,
	SOUTH => 3,
	WEST  => 4,

	# Resizing by corner
	NORTHWEST => 5,
	NORTHEAST => 6,
	SOUTHWEST => 7,
	SOUTHEAST => 8,
};

=head1 METHODS

=cut

=head2 on_mouse

Handle mouse events.

We can be in one of three states here: a mouse press, a drag event, or a release.

We delegate each of these to separate methods.

=cut

sub on_mouse {
	my $self = shift;
	my ($ev, $button, $line, $col) = @_;
	return $self->mouse_release($line, $col) if $ev eq 'release';
	return unless $button & 1;

	return $self->mouse_press($line, $col) if $ev eq 'press';
	return $self->mouse_drag($line, $col) if $ev eq 'drag';
}

=head2 mouse_press

Handle a mouse press event.

We're either in:

=over 4

=item * a corner - start resizing in both directions

=item * an edge - start resizing in one dimension

=item * the title bar - start moving the window

=back

=cut

sub mouse_press {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;

	if(my $corner = $self->position_is_corner($line, $col)) {
		$self->start_resize_from_corner($corner);
	} elsif($self->position_is_close($line, $col)) {
		# Close button... probably need some way to indicate when
		# this happens, Tickit::Window doesn't appear to have set_on_closed ?
		$self->window->clear;
		$self->window->close;
	} elsif($self->position_is_title($line, $col)) {
		$self->start_moving($line, $col);
	} elsif(my $edge = $self->position_is_edge($line, $col)) {
		$self->start_resize_from_edge($edge);
	}
	return 1;
}

=head2 position_is_corner

If this location is a corner of the window, return the
appropriate constant (NORTHEAST, NORTHWEST, SOUTHEAST,
SOUTHWEST), otherwise returns false.

=cut

sub position_is_corner {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	if($line == 0) {
		return NORTHWEST if $col == 0;
		return NORTHEAST if $col == $win->cols - 1;
		return 0;
	}
	return 0 unless $line == $win->lines - 1;
	return SOUTHWEST if $col == 0;
	return SOUTHEAST if $col == $win->cols - 1;
	return 0;
}

=head2 position_is_corner

If this location is an edge for this window, return the
appropriate constant (NORTH, EAST, SOUTH, WEST), otherwise
returns false.

=cut

sub position_is_edge {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	return NORTH if $line == 0;
	return WEST if $col == 0;
	return SOUTH if $line == $win->lines - 1;
	return EAST if $col == $win->cols - 1;
	return 0;
}

=head2 position_is_title

If this location is somewhere in the title (currently defined
as "top row, apart from corners and close button), returns true.

=cut

sub position_is_title {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	return 1 if $line == 0 && $col > 0 && $col < ($win->cols - 2);
	return 0;
}

=head2 position_is_close

Returns true if this location is the close button.

=cut

sub position_is_close {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	return 1 if $line == 0 && $col == $win->cols - 2;
	return 0;
}

=head2 start_resize_from_corner

Start resizing from a corner.

=cut

sub start_resize_from_corner {
	my $self = shift;
	my $corner = shift;
	my $win = $self->window or return;
	$self->{mouse_action} = 'resize_from_corner';
	$self->{corner} = $corner;
	$self->{origin} = {
		map { $_ => $win->$_ } qw(top left bottom right)
	};
	$win->{steal_input} = 1;
}

=head2 start_resize_from_edge

Start resizing from an edge.

=cut

sub start_resize_from_edge {
	my $self = shift;
	my $edge = shift;
	my $win = $self->window or return;
	$self->{mouse_action} = 'resize_from_edge';
	$self->{edge} = $edge;
	$self->{origin} = {
		map { $_ => $win->$_ } qw(top left bottom right)
	};
	$win->{steal_input} = 1;
}

=head2 start_moving

Start moving the window.

=cut

sub start_moving {
	my $self = shift;
	my ($line, $col) = @_;
	my $win = $self->window or return;
	$self->{mouse_action} = 'move';
	$self->{origin} = {
		line => $line,
		col => $col,
	};
	$win->{steal_input} = 1;
}

=head2 mouse_drag

Deal with our drag events by changing window geometry
accordingly.

=cut

sub mouse_drag {
	my ($self, $line, $col) = @_;
	if(my $action = $self->{mouse_action}) {
		$self->$action($line, $col);
	} else {
		# Dragging one window over another is probably
		# going to raise this warning...
		# die "Unknown action";
	}
}

sub move {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	my $top = $win->top + ($line - $self->{origin}{line});
	my $left = $win->left + ($col - $self->{origin}{col});
	$win->reposition(
		$top,
		$left,
	);
}

sub resize_from_corner {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	if($self->{corner} == SOUTHEAST) {
		$win->change_geometry(
			$win->top,
			$win->left,
			$line + 1,
			$col + 1,
		);
	} elsif($self->{corner} == NORTHEAST) {
		$win->change_geometry(
			$win->top + $line,
			$win->left,
			$win->bottom - ($win->top + $line),
			$col + 1,
		);
	} elsif($self->{corner} == NORTHWEST) {
		$win->change_geometry(
			$win->top + $line,
			$win->left + $col,
			$win->bottom - ($win->top + $line),
			$win->right - ($win->left + $col),
		);
	} elsif($self->{corner} == SOUTHWEST) {
		$win->change_geometry(
			$win->top,
			$win->left + $col,
			$line + 1,
			$win->right - ($win->left + $col),
		);
	}
}

sub resize_from_edge {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	if($self->{edge} == NORTH) {
		$win->change_geometry(
			$win->top + $line,
			$win->left,
			$win->bottom - ($win->top + $line),
			$win->cols,
		);
	} elsif($self->{edge} == EAST) {
		$win->change_geometry(
			$win->top,
			$win->left,
			$win->lines,
			$col + 1,
		);
	} elsif($self->{edge} == SOUTH) {
		$win->change_geometry(
			$win->top,
			$win->left,
			$line + 1,
			$win->cols,
		);
	} elsif($self->{edge} == WEST) {
		$win->change_geometry(
			$win->top,
			$win->left + $col,
			$win->lines,
			$win->right - ($win->left + $col),
		);
	}
}

=head2 mouse_release

On release make sure we hand back input to the previous handler.

=cut

sub mouse_release {
	my ($self, $v) = @_;
	my $win = $self->window or die "no window?";
	$win->{steal_input} = 0;
	$self->{mouse_action} = '';
}

1;

__END__

=head1 SEE ALSO

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2012-2013. Licensed under the same terms as Perl itself.

