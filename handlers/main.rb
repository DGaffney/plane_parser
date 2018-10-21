class Site < Sinatra::Base
  # sets root as the parent-directory of the current file
  set :root, File.join(File.dirname(__FILE__), '..')
  # sets the view directory correctly
  set :views, Proc.new { File.join(root, "views") } 

  get '/vote_amr' do
    @amr = AvionicsMatchRecord.find(id: AvionicsMatchRecord.where(:nontrivial_candidates.ne => {}).only(:id).collect(&:id).shuffle.first)
    @amr.seen_count ||= 0
    @amr.seen_count += 1
    @amr.save!
    erb :vote_amr, :layout => :'layouts/main'
  end

  get "/vote_amr/:amr_id/:index" do
    @amr = AvionicsMatchRecord.find(id: params[:amr_id])
    if @amr.candidate_vote_list[params[:index].to_i].nil?
      candidate = @amr.nontrivial_candidates[params[:index].to_i][1]
      @amr.candidate_vote_list[params[:index].to_i] = {avionic_type: candidate["avionic_type"], manufacturer: candidate["manufacturer"], device: candidate["device"], count: 0}
    end
    @amr.candidate_vote_list[params[:index].to_i][:count] += 1
    @amr.save!
    redirect "/vote_amr"
  end
end