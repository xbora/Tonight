class EventsController < ApplicationController
  # GET /events
  # GET /events.xml
  
  require 'rubygems'
  include LastFm
  last_fm
  
  def index
    #@events = Event.all
    if (cookies[:cit] == "-")
      @event_loc = "Amsterdam"
    else
      @event_loc = cookies[:cit].to_s
    end
    @event_loc = "Amsterdam"
    
    i = 1
    @all_events = Array[]
    
    while i < 7 do
            
    @geo_events = lastfm_get_geo_events(@event_loc, i, 15)
    @all_events += @geo_events
    
    puts @geo_events.inspect
    
  
      @geo_events.each do |event|
      
      puts event["title"] + " at " + event["venue"] + " on " + event["date"].to_s
      
      end 
      
      i += 1
      
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @events }
    end
  end

  # GET /events/1
  # GET /events/1.xml
  def show
    @event = Event.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/new
  # GET /events/new.xml
  def new
    @event = Event.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/1/edit
  def edit
    @event = Event.find(params[:id])
  end

  # POST /events
  # POST /events.xml
  def create
    @event = Event.new(params[:event])

    respond_to do |format|
      if @event.save
        format.html { redirect_to(@event, :notice => 'Event was successfully created.') }
        format.xml  { render :xml => @event, :status => :created, :location => @event }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /events/1
  # PUT /events/1.xml
  def update
    @event = Event.find(params[:id])

    respond_to do |format|
      if @event.update_attributes(params[:event])
        format.html { redirect_to(@event, :notice => 'Event was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.xml
  def destroy
    @event = Event.find(params[:id])
    @event.destroy

    respond_to do |format|
      format.html { redirect_to(events_url) }
      format.xml  { head :ok }
    end
  end
end
