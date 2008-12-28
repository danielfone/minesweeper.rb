#!/usr/bin/ruby -w
#
# Minesweeper
#
require 'rubygems';
require 'termios';
require 'terminfo';

$colours = {
  'Black'       => '0;30',
  'Dark Gray'   => '1;30',
  'Blue'		    => '0;34',
  'Light Blue'  => '1;34',
  'Green'		    => '0;32',
  'Light Green'	=> '1;32',
  'Cyan'		    => '0;36',
  'Light Cyan'	=> '1;36',
  'Red'		      => '0;31',
  'Light Red'		=> '1;31',
  'Purple'		  => '0;35',
  'Light Purple'=> '1;35',
  'Brown'		    => '0;33',
  'Yellow'		  => '1;33',
  'Light Gray'	=> '0;37',
  'White'		    => '1;37',
}

class Square
  attr_reader :isMine, :isHidden, :isFlagged;

  def initialize(field)
    @field = field;
    @isMine = false;
    @isHidden = true;
    @touching = nil;
    @neighbours = [];
    @isFlagged = false;
  end

  def mkMine
    @isMine = true;
  end

  def select(select=true)
    x = @field.xOff + self.x;
    y = @field.yOff + self.y;
    TermInfo.control("cup", y, x);
#    system("tput cup #{y} #{x}");
  end

  def show
    others = [self];
    while others.size > 0 do
      sq = others.pop;
      sq.reveal if sq.isHidden;
      next if sq.touching > 0 or sq.isMine;
      sq.neighbours.each do |n|
        next if not n.isHidden;
        next if others.include?(n);
        others.push(n);
      end
    end
  end

  def reveal
    # Unflag if we've marked it
    self.mark if @isFlagged;
    @isHidden = false;
    self.select;
    self.print;
    # Blow up!
    if @isMine then
      @field.isFinished = true;
      return
    end

  end

  def mark
    return if not @isHidden;
    @field.marked(-1) if @isFlagged;
    @field.marked(1) if not @isFlagged;
    @isFlagged = !@isFlagged;
    self.select;
    self.print;
    if @field.minesRemaining == 0 and @field.isClear then
      @field.isFinished = true;
    end
  end

  def printColour(char)
    if char == 'X' then
      colour = $colours['Black'];
    elsif char == '1' then
      colour = $colours['Blue'];
    elsif char == '2' then
      colour = $colours['Green'];
    elsif char == '3' then
      colour = $colours['Red'];
    elsif char == '4' then
      colour = $colours['Purple'];
    elsif char == '?'
      colour = $colours['White']+';47';
    elsif char == '+'
      colour = $colours['Light Gray'];
    elsif char == 'M'
      colour = $colours['White']+';40';
    end;

    printf "\033[#{colour}m#{char}\033[0m";
    $stdout.flush;
  end

  def print
    if @isFlagged then
      self.printColour('M');
    elsif @isHidden then
      self.printColour('?');
    elsif @isMine then
      self.printColour('X');
    elsif self.touching > 0
      self.printColour(self.touching.to_s);
    else
      self.printColour('+');
    end;
  end

  def touching
    return @touching if @touching;
    t = 0;
    self.neighbours.each do |n|
      t += 1 if n.isMine;
    end
    @touching = t;
    return t;
  end

  def neighbours
    return @neighbours if @neighbours.length > 0;
    nbours = [];
    for y in self.y-1..self.y+1 do
      break if y >= @field.height;
      next if y < 0;
      for x in self.x-1..self.x+1 do
        break if x >= @field.width;
        next if x < 0;
        next if x == self.x and y == self.y;
          nbours.push(@field.square(x,y));
      end
    end
    @neighbours = nbours;
    return nbours;
  end

  def y
    @field.height.times do |i|
      return i if @field.row(i).include?(self);
    end
    return nil;
  end

  def x
    @field.height.times do |i|
      if @field.row(i).include?(self) then
        return @field.row(i).index(self);
      end
    end
    return nil;
  end

end

class Field
  attr_reader :width, :height, :isFinished, :xOff, :yOff;
  attr_writer :isFinished;

  def initialize(width, height)
    @width = width;
    @height = height;
    @isFinished = false;
    @isClear = false;
    @xOff = 2;
    @yOff = 6;
    @marked = 0;
    @field = [];
    height.times do
      line = []
      width.times do
        sq = Square.new(self);
        line.push(sq)
      end
      @field.push(line);
    end
    
    @mines = [];
    mineCount.times do 
      x = rand(width);
      y = rand(height);

      while @field[y][x].isMine do
        x = rand(width);
        y = rand(height);
      end
      @field[y][x].mkMine;
      @mines.push(@field[y][x]);
    end
  end

  def isClear
    @mines.each do |m|
      return false if not m.isFlagged;
    end
    return true;
  end

  def square(x, y)
    @field[y][x];
  end

  def row(y)
    @field[y];
  end

  def print
    puts "  \033[0;33m*_*_*_*\033[0m \033[0;34mMinesweeper v \033[35m2\033[0m \033[0;33m*_*_*_*\033[0m";
    puts
    puts "  \033[1mMove:\033[0m Arrows|Home|End|PgUp|PgDown";
    puts "  \033[1mReveal:\033[0m Space;   \033[1mMark:\033[0m m";
    puts
    puts '  Mines left: '+self.minesRemaining.to_s;
    @field.each do |line|
      printf '  ';
      line.each do |sq|
        sq.print
      end
      puts
    end
  end

  def minesRemaining
    mineCount - @marked
  end

  def mineCount
    (@width * @height * 0.1).round;
  end

  def selectLast
    self.square(@width-1, @height-1).select;
  end

  def marked(count)
    @marked += count;
    TermInfo::control("cup", @yOff-1, @xOff+12);
    puts self.minesRemaining.to_s+' ';
  end

end

def setBuffer(on)
  term = Termios::getattr($stdin);
  if on then
    term.c_lflag |= ( Termios::ECHO | Termios::ICANON );
  else
    term.c_lflag &= ~Termios::ICANON;
    term.c_lflag &= ~Termios::ECHO
  end
  Termios::setattr($stdin, Termios::TCSANOW, term);
end


def usage
  puts "USAGE: #{$0} width height";
  puts "Minimum grid size 3x3";
  puts "Move with the arrow keys";
  puts "Reveal with space bar";
  puts "Mark with 'm'";
  exit;
end

# Main program starts here
usage if ARGV.length < 2;
usage if not ARGV[0].to_i or ARGV[0].to_i < 3;
usage if not ARGV[1].to_i or ARGV[1].to_i < 3;

# Start here
width = ARGV[0].to_i;
height = ARGV[1].to_i;
puts "Starting with grid #{width} x #{height}";

system "clear";
x = 0;
y = 0;
begin
  setBuffer(false);
  field = Field.new(width, height);
  field.print;
  while not field.isFinished do
    currentSq = field.square(x,y);
    currentSq.select;
      
    begin
      key = $stdin.getc;
    rescue Interrupt
      exit;
    end
    
    if key == 27 then
      # Grab our control chars
      key += $stdin.getc;
      key += $stdin.getc;
      if key == 183 and y > 0 then # Up
        y -= 1;
      elsif key == 184 and y < height-1 then # Down
        y += 1;
      elsif key == 185 and x < width-1 then # Right
        x += 1;
      elsif key == 186 and x > 0 then # Left
        x -= 1;
      elsif key == 167 then # Home
        x = 0;
      elsif key == 170 then # End
        x = field.width-1;
      elsif key == 171 then # PgUp
        y = 0;
      elsif key == 172 then # PgDown
        y = field.height-1;
      end;

    elsif key == 32 then # Space
      currentSq.show;
    
    elsif key == 109 then # m
      currentSq.mark;
    
    end
  end
ensure
  # Reset
  setBuffer(true);
  field.selectLast;
  puts;
end


if field.isClear then
  puts 'Well done';
else
  puts 'BLAM!';
end
