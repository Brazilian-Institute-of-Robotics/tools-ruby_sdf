require 'sdf/test'

module SDF
    describe SphericalCoordinates do
        it "returns WGS84 as the default surface model" do
            coord = SphericalCoordinates.new
            assert_equal "WGS-84", coord.surface_model
        end
        it "returns the surface model content as-is" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><surface_model>TEST</surface_model></spherical_coordinates>")
            assert_equal "TEST", coord.surface_model
        end
        it "returns the latitude in degrees" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><latitude_deg>2.2</latitude_deg></spherical_coordinates>")
            assert_equal 2.2, coord.latitude_deg
        end
        it "raises if the latitude is not defined" do
            coord = SphericalCoordinates.new
            assert_raises(Invalid) do
                coord.latitude_deg
            end
        end
        it "returns the longitude in degrees" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><longitude_deg>2.2</longitude_deg></spherical_coordinates>")
            assert_equal 2.2, coord.longitude_deg
        end
        it "raises if the longitude is not defined" do
            coord = SphericalCoordinates.new
            assert_raises(Invalid) do
                coord.longitude_deg
            end
        end
        it "returns the elevation" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><elevation>2.2</elevation></spherical_coordinates>")
            assert_equal 2.2, coord.elevation
        end
        it "returns a zero elevation by default" do
            coord = SphericalCoordinates.new
            assert_equal 0, coord.elevation
        end
        it "returns the heading in radians" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><heading_deg>2.2</heading_deg></spherical_coordinates>")
            assert_equal 2.2 * Math::PI / 180, coord.heading
        end
        it "returns a zero heading by default" do
            coord = SphericalCoordinates.new
            assert_equal 0, coord.heading
        end

        describe "the UTM conversion functionality" do
            it "automatically pick the UTM zone if given none - north hemishpere" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>48.858093</latitude_deg>
                        <longitude_deg>2.294694</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 448_265.91, utm.easting, 0.01
                assert_in_delta 5_411_920.65, utm.northing, 0.01
                assert utm.north?
            end
            it "automatically pick the UTM zone if given none - south hemishpere" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-22.970722</latitude_deg>
                        <longitude_deg>-43.182365</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 686_336.05, utm.easting, 0.01
                assert_in_delta 7_458_567.56, utm.northing, 0.01
                refute utm.north?
            end

            it "allows to force the UTM zone if given one" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-22.966296</latitude_deg>
                        <longitude_deg>-41.991291</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm(zone: 23)
                assert_in_delta 807_548, utm.easting, 5000
                assert_in_delta 7_457_048, utm.northing, 1
                refute utm.north?
            end

            it "allows to force the UTM northing if given (force north when south)" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-0.001</latitude_deg>
                        <longitude_deg>-51.081063</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 490_980, utm.easting, 1
                assert_in_delta 9_999_889, utm.northing, 1
                refute utm.north?

                utm = coord.utm(north: true)
                assert_in_delta 490_980, utm.easting, 1
                assert_in_delta -111, utm.northing, 1
                assert utm.north?
            end
        end
    end
end

