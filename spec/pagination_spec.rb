require 'spec_helper'

RSpec.describe UsersController, type: :request do
  describe 'GET /users' do
    let!(:user) { }
    let(:params) do
      {
        page: { number: 'Nan', size: 'NaN' },
        sort: '-created_at'
      }
    end

    before do
      get(users_path, params: params, headers: jsonapi_headers)
    end

    it do
      expect(response_json['data'].size).to eq(0)
      expect(response_json['meta'])
        .to eq(
          'many' => true,
          'pagination' => {
            'current' => 1,
            'total_page' => 1,
            'total_count' => 0,
          }
        )
    end

    def query_str(parms, page: nil)
      parms = parms.deep_merge(page: { number: page }) if page

      arg_params = parms.dup
      if page == 1
        arg_params.delete(:page)
      end

      "?#{CGI.unescape(arg_params.to_query)}"
    end

    context 'with users' do
      let(:first_user) { create_user }
      let(:second_user) { create_user }
      let(:third_user) { create_user }
      let(:users) { [first_user, second_user, third_user] }
      let(:user) { users.last }

      context 'returns users with pagination links' do
        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].size).to eq(3)
          expect(response_json['data'][0]).to have_id(third_user.id.to_s)
          expect(response_json['data'][1]).to have_id(second_user.id.to_s)
          expect(response_json['data'][2]).to have_id(first_user.id.to_s)

          expect(response_json).to have_link('current')
          expect(response_json).to have_link(:prev)
          expect(response_json).to have_link(:next)
          expect(response_json).to have_link(:first)
          expect(response_json).to have_link(:last)

          query = CGI.unescape(params.except(:page).to_query)
          expect(URI.parse(response_json['links']['current']).query).to eq(query)
        end

        context 'on page 2 out of 3' do
          let(:as_list) { }
          let(:params) do
            {
              page: { number: 2, size: 1 },
              sort: '-created_at',
              as_list: as_list
            }.reject { |_k, _v| _v.blank? }
          end

          context 'on an array of resources' do
            let(:as_list) { true }

            it 'should exclude' do
              expect(response).to have_http_status(:ok)
              expect(response_json['data'].size).to eq(1)
              expect(response_json['data'][0]).to have_id(second_user.id.to_s)

              expect(response_json['meta']['pagination']).to eq(
                'current' => 2,
                'total_count' => 3,
                'total_page' => 3
              )
              pp response_json['links']
              expect(response_json['links']).to eq(
                'current' => query_str(params),
                'first' => query_str(params, page: 1),
                'prev' => query_str(params, page: 1),
                'next' => query_str(params, page: 3),
                'last' => query_str(params, page: 3),
              )
            end
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)
            expect(response_json['data'][0]).to have_id(second_user.id.to_s)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 2,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 1),
              'next' => query_str(params, page: 3),
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            qry = CGI.unescape(params.to_query)
            expect(URI.parse(response_json['links']['current']).query)
              .to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['current']).query)
              .to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 3 }).to_query)
            expect(URI.parse(response_json['links']['next']).query).to eq(qry)
            expect(URI.parse(response_json['links']['last']).query).to eq(qry)
          end
        end

        context 'on page 3 out of 3' do
          let(:params) do
            {
              page: { number: 3, size: 1 }
            }
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 3,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 2),
              'next' => nil,
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)
          end
        end

        context 'on paging beyond the last page' do
          let(:as_list) { }
          let(:params) do
            {
              page: { number: 5, size: 1 },
              as_list: as_list
            }.reject { |_k, _v| _v.blank? }
          end

          context 'on an array of resources' do
            let(:as_list) { true }

            it do
              expect(response).to have_http_status(:ok)
              expect(response_json['data'].size).to eq(0)

              expect(response_json['meta']['pagination']).to eq(
                'current' => 5,
                'total_count' => 3,
                'total_page' => 3
              )
              expect(response_json['links']).to eq(
                'current' => query_str(params),
                'first' => query_str(params, page: 1),
                'prev' => query_str(params, page: 4),
                'next' => nil,
                'last' => query_str(params, page: 3),
              )
            end
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(0)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 5,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 4),
              'next' => nil,
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 4 }).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)
          end
        end

        context 'on page 1 out of 3' do
          let(:params) do
            {
              page: { size: 1, number: 1 },
              sort: '-created_at'
            }
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)
            expect(response_json['data'][0]).to have_id(third_user.id.to_s)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 1,
              'total_count' => 3,
              'total_page' => 3,
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params, page: 1),
              'first' => query_str(params, page: 1),
              'prev' => nil,
              'next' => query_str(params, page: 2),
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.except(:page).to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['next']).query).to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 3 }).to_query)
            expect(URI.parse(response_json['links']['last']).query).to eq(qry)
          end
        end
      end
    end
  end
end
